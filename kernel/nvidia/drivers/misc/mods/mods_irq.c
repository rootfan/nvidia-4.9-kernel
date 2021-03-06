/*
 * mods_irq.c - This file is part of NVIDIA MODS kernel driver.
 *
 * Copyright (c) 2008-2018, NVIDIA CORPORATION.  All rights reserved.
 *
 * NVIDIA MODS kernel driver is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * NVIDIA MODS kernel driver is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with NVIDIA MODS kernel driver.
 * If not, see <http://www.gnu.org/licenses/>.
 */

#include "mods_internal.h"

#include <linux/sched.h>
#include <linux/poll.h>
#include <linux/interrupt.h>
#include <linux/pci_regs.h>
#if defined(MODS_TEGRA) && defined(CONFIG_OF_IRQ) && defined(CONFIG_OF)
#include <linux/of.h>
#include <linux/of_irq.h>
#include <linux/io.h>
#include <linux/platform_device.h>
#include <linux/of_device.h>
#endif

#define PCI_VENDOR_ID_NVIDIA 0x10de
#define INDEX_IRQSTAT(irq)	(irq / BITS_NUM)
#define POS_IRQSTAT(irq)	 (irq & (BITS_NUM - 1))

/* MSI */
#define PCI_MSI_MASK_BIT	16
#define MSI_CONTROL_REG(base)		(base + PCI_MSI_FLAGS)
#define IS_64BIT_ADDRESS(control)	(!!(control & PCI_MSI_FLAGS_64BIT))
#define MSI_DATA_REG(base, is64bit) \
	((is64bit == 1) ? base + PCI_MSI_DATA_64 : base + PCI_MSI_DATA_32)
#define TOP_TKE_TKEIE_WDT_MASK(i)	(1 << (16 + 4 * (i)))
#define TOP_TKE_TKEIE(i)		(0x100 + 4 * (i))

struct nv_device {
	char		  name[20];
	struct mods_priv *isr_pri;
	void		 *pri[MODS_CHANNEL_MAX];
};

/*********************
 * PRIVATE FUNCTIONS *
 *********************/
static struct mods_priv mp;
static struct nv_device nv_dev = { "nvidia mods", &mp, {0} };

static struct mods_priv *get_all_data(void)
{
	return &mp;
}

static struct nv_device *get_dev(void)
{
	return &nv_dev;
}

#ifdef CONFIG_PCI
int mods_enable_device(struct mods_file_private_data *priv,
				  struct pci_dev *pdev)
{
	int                  ret   = -1;
	struct en_dev_entry *entry = priv->enabled_devices;

	mods_debug_printk(DEBUG_ISR_DETAILED, "vendor %x device %x device %x function %x\n",
			pdev->vendor, pdev->device,
			(unsigned int)PCI_SLOT(pdev->devfn),
			(unsigned int)PCI_FUNC(pdev->devfn));

	while (entry != 0) {
		if (entry->dev == pdev)
			return 0;
		entry = entry->next;
	}

	ret = pci_enable_device(pdev);
	if (ret == 0) {
		entry = kzalloc(sizeof(*entry), GFP_KERNEL | __GFP_NORETRY);
		if (unlikely(!entry))
			return 0;
		entry->dev = pdev;
		entry->next = priv->enabled_devices;
		priv->enabled_devices = entry;
		pci_set_drvdata(pdev, entry);
		mods_debug_printk(DEBUG_ISR_DETAILED,
			"pci_set_drvdata for vendor %x device %x device %x function %x\n",
			pdev->vendor, pdev->device,
			(unsigned int)PCI_SLOT(pdev->devfn),
			(unsigned int)PCI_FUNC(pdev->devfn));
	} else {
		mods_debug_printk(DEBUG_ISR_DETAILED,
			"pci_set_drvdata failed for vendor %x device %x device %x function %x ret=%d\n",
			pdev->vendor, pdev->device,
			(unsigned int)PCI_SLOT(pdev->devfn),
			(unsigned int)PCI_FUNC(pdev->devfn),
			ret);
	}
	return ret;
}

void mods_disable_device(struct pci_dev *pdev)
{
	struct en_dev_entry *dpriv = pci_get_drvdata(pdev);

	if (dpriv)
		pci_set_drvdata(pdev, NULL);

	pci_disable_device(pdev);
}
#endif

static unsigned int get_cur_time(void)
{
	/* This is not very precise, sched_clock() would be better */
	return jiffies_to_usecs(jiffies);
}

static int id_is_valid(unsigned char channel)
{
	if (channel <= 0 || channel > MODS_CHANNEL_MAX)
		return -EINVAL;

	return OK;
}

static inline int mods_check_interrupt(struct dev_irq_map *t)
{
	int ii = 0;
	int valid = 0;

	/* For MSI - we always treat it as pending (must rearm later). */
	/* For non-GPU devices - we can't tell. */
	if (t->mask_info_cnt == 0)
		return true;

	for (ii = 0; ii < t->mask_info_cnt; ii++) {
		if (!t->mask_info[ii].dev_irq_state ||
		    !t->mask_info[ii].dev_irq_mask_reg)
			continue;

		/* GPU device */
		if (t->mask_info[ii].mask_type == MODS_MASK_TYPE_IRQ_DISABLE64)
			valid |= ((*(u64 *)t->mask_info[ii].dev_irq_state &&
			*(u64 *)t->mask_info[ii].dev_irq_mask_reg) != 0);
		else
			valid |= ((*t->mask_info[ii].dev_irq_state &&
			     *t->mask_info[ii].dev_irq_mask_reg) != 0);
	}
	return valid;
}

static void mods_disable_interrupts(struct dev_irq_map *t)
{
	u32 ii = 0;

	for (ii = 0; ii < t->mask_info_cnt; ii++) {
		if (t->mask_info[ii].dev_irq_disable_reg &&
		   t->mask_info[ii].mask_type == MODS_MASK_TYPE_IRQ_DISABLE64) {
			if (t->mask_info[ii].irq_and_mask == 0)
				*(u64 *)t->mask_info[ii].dev_irq_disable_reg =
				t->mask_info[ii].irq_or_mask;
			else
				*(u64 *)t->mask_info[ii].dev_irq_disable_reg =
				(*(u64 *)t->mask_info[ii].dev_irq_mask_reg &
				t->mask_info[ii].irq_and_mask) |
				t->mask_info[ii].irq_or_mask;
		} else if (t->mask_info[ii].dev_irq_disable_reg) {
			if (t->mask_info[ii].irq_and_mask == 0) {
				*t->mask_info[ii].dev_irq_disable_reg =
				t->mask_info[ii].irq_or_mask;
			} else {
				*t->mask_info[ii].dev_irq_disable_reg =
				(*t->mask_info[ii].dev_irq_mask_reg &
				t->mask_info[ii].irq_and_mask) |
				t->mask_info[ii].irq_or_mask;
			}
		}
	}
	if ((ii == 0) && t->type == MODS_IRQ_TYPE_CPU) {
		mods_debug_printk(DEBUG_ISR, "IRQ_DISABLE_NOSYNC ");
		disable_irq_nosync(t->apic_irq);
	}
}

static const char *mods_irq_type_name(u8 irq_type)
{
	switch (irq_type) {
	case MODS_IRQ_TYPE_INT:
		return "INTx";
	case MODS_IRQ_TYPE_MSI:
		return "MSI";
	case MODS_IRQ_TYPE_CPU:
		return "CPU";
	case MODS_IRQ_TYPE_MSIX:
		return "MSI-X";
	default:
		return "unknown";
	}
}

static void rec_irq_done(struct nv_device *dev,
			 unsigned char channel,
			 struct dev_irq_map *t,
			 unsigned int irq_time)
{
	struct irq_q_info *q;
	struct mods_priv *pmp = dev->isr_pri;
	struct mods_file_private_data *private_data = dev->pri[channel - 1];

	/* Get interrupt queue */
	q = &pmp->rec_info[channel - 1];

	/* Don't do anything if the IRQ has already been recorded */
	if (q->head != q->tail) {
		unsigned int i;

		for (i = q->head; i != q->tail; i++) {
			struct irq_q_data *pd
					= q->data+(i & (MODS_MAX_IRQS - 1));

			if ((pd->irq == t->apic_irq) &&
			    (!t->dev || (pd->dev == t->dev)))
				return;
		}
	}

	/* Print an error if the queue is full */
	/* This is deadly! */
	if (q->tail - q->head == MODS_MAX_IRQS) {
		mods_error_printk("IRQ queue is full\n");
		return;
	}

	/* Record the device which generated the IRQ in the queue */
	q->data[q->tail & (MODS_MAX_IRQS - 1)].dev       = t->dev;
	q->data[q->tail & (MODS_MAX_IRQS - 1)].irq       = t->apic_irq;
	q->data[q->tail & (MODS_MAX_IRQS - 1)].irq_index = t->entry;
	q->data[q->tail & (MODS_MAX_IRQS - 1)].time      = irq_time;
	q->tail++;

#ifdef CONFIG_PCI
	if (t->dev) {
		mods_debug_printk(DEBUG_ISR_DETAILED,
			"%04x:%x:%02x.%x %s IRQ 0x%x time=%uus\n",
				  (unsigned int)(pci_domain_nr(t->dev->bus)),
				  (unsigned int)(t->dev->bus->number),
				  (unsigned int)PCI_SLOT(t->dev->devfn),
				  (unsigned int)PCI_FUNC(t->dev->devfn),
			mods_irq_type_name(t->type),
			t->apic_irq,
			irq_time);
	} else
#endif
		mods_debug_printk(DEBUG_ISR_DETAILED,
			"CPU IRQ 0x%x, time=%uus\n",
			t->apic_irq,
			irq_time);

	/* Wake MODS to handle the interrupt */
	if (private_data) {
		spin_unlock(&pmp->lock);
		wake_up_interruptible(&private_data->interrupt_event);
		spin_lock(&pmp->lock);
	}
}

/* mods_irq_handle - interrupt function */
static irqreturn_t mods_irq_handle(int irq, void *data
#ifndef MODS_IRQ_HANDLE_NO_REGS
			, struct pt_regs *regs
#endif
)
{
	struct nv_device *dev = (struct nv_device *)data;
	struct mods_priv *pmp = dev->isr_pri;
	struct dev_irq_map *t = NULL;
	unsigned char channel_idx;
	unsigned long flags = 0;
	int found = 0;
	unsigned int irq_time = get_cur_time();

	spin_lock_irqsave(&pmp->lock, flags);

	for (channel_idx = 0; channel_idx < MODS_CHANNEL_MAX; channel_idx++) {
		if (!(pmp->channel_flags & (1 << channel_idx)))
			continue;

		list_for_each_entry(t, &pmp->irq_head[channel_idx], list) {
			if ((t->apic_irq == irq) && mods_check_interrupt(t)) {
				/* Disable interrupts on this device to avoid
				 * interrupt storm
				 */
				mods_disable_interrupts(t);

				/* Record IRQ for MODS and wake MODS up */
				rec_irq_done(dev, channel_idx+1, t, irq_time);
				found |= 1;

				/* MSI, MSI-X and CPU interrupts are not shared,
				 * so stop looking
				 */
				if (t->type != MODS_IRQ_TYPE_INT) {
					channel_idx = MODS_CHANNEL_MAX;
					break;
				}
			}
		}
	}

	spin_unlock_irqrestore(&pmp->lock, flags);
	return IRQ_RETVAL(found);
}

static int mods_lookup_irq(unsigned char channel, struct pci_dev *pdev,
						   unsigned int irq)
{
	unsigned char channel_idx;
	struct mods_priv *pmp = get_all_data();
	int ret = IRQ_NOT_FOUND;

	LOG_ENT();

	for (channel_idx = 0; channel_idx < MODS_CHANNEL_MAX; channel_idx++) {
		struct dev_irq_map *t    = NULL;
		struct dev_irq_map *next = NULL;

		list_for_each_entry_safe(t,
					 next,
					 &pmp->irq_head[channel_idx],
					 list) {

			if ((t->apic_irq == irq) &&
				(!pdev || (t->dev == pdev))) {
				if (channel == 0) {
					ret = IRQ_FOUND;
				} else {
					ret = (channel == channel_idx + 1)
						  ? IRQ_FOUND : IRQ_NOT_FOUND;
				}

				/* Break out of the outer loop */
				channel_idx = MODS_CHANNEL_MAX;
				break;
			}
		}
	}

	LOG_EXT();
	return ret;
}

#ifdef CONFIG_PCI
static int is_nvidia_device(struct pci_dev *pdev)
{
	unsigned short class_code, vendor_id, device_id;

	pci_read_config_word(pdev, PCI_CLASS_DEVICE, &class_code);
	pci_read_config_word(pdev, PCI_VENDOR_ID, &vendor_id);
	pci_read_config_word(pdev, PCI_DEVICE_ID, &device_id);
	if (((class_code == PCI_CLASS_DISPLAY_VGA) ||
	    (class_code == PCI_CLASS_DISPLAY_3D)) && (vendor_id == 0x10DE)) {
		return 1;
	}
	return 0;
}
#endif

#ifdef CONFIG_PCI
static void setup_mask_info(struct dev_irq_map *newmap,
			    struct MODS_REGISTER_IRQ_4 *p,
			    struct pci_dev *pdev)
{
	/* account for legacy adapters */
	char *bar = newmap->dev_irq_aperture;
	u32 ii = 0;

	if ((p->mask_info_cnt == 0) && is_nvidia_device(pdev)) {
		newmap->mask_info_cnt = 1;
		newmap->mask_info[0].dev_irq_mask_reg = (u32 *)(bar+0x140);
		newmap->mask_info[0].dev_irq_disable_reg = (u32 *)(bar+0x140);
		newmap->mask_info[0].dev_irq_state = (u32 *)(bar+0x100);
		newmap->mask_info[0].irq_and_mask = 0;
		newmap->mask_info[0].irq_or_mask = 0;
		return;
	}
	/* setup for new adapters */
	newmap->mask_info_cnt = p->mask_info_cnt;
	for (ii = 0; ii < p->mask_info_cnt; ii++) {
		newmap->mask_info[ii].dev_irq_state =
		    (u32 *)(bar + p->mask_info[ii].irq_pending_offset);
		newmap->mask_info[ii].dev_irq_mask_reg =
		    (u32 *)(bar + p->mask_info[ii].irq_enabled_offset);
		newmap->mask_info[ii].dev_irq_disable_reg =
		    (u32 *)(bar + p->mask_info[ii].irq_disable_offset);
		newmap->mask_info[ii].irq_and_mask = p->mask_info[ii].and_mask;
		newmap->mask_info[ii].irq_or_mask = p->mask_info[ii].or_mask;
		newmap->mask_info[ii].mask_type = p->mask_info[ii].mask_type;
	}
}
#endif

static int add_irq_map(unsigned char channel,
			   struct pci_dev *pdev,
			   struct MODS_REGISTER_IRQ_4 *p, u32 irq, u32 entry)
{
	u32 irq_type = MODS_IRQ_TYPE_FROM_FLAGS(p->irq_flags);
	struct dev_irq_map *newmap = NULL;
	struct mods_priv *pmp = get_all_data();
	struct nv_device *nvdev = get_dev();

	LOG_ENT();

	/* Allocate memory for the new entry */
	newmap = kmalloc(sizeof(*newmap), GFP_KERNEL | __GFP_NORETRY);
	if (unlikely(!newmap)) {
		LOG_EXT();
		return -ENOMEM;
	}

	/* Fill out the new entry */
	newmap->apic_irq = irq;
	newmap->dev = pdev;
	newmap->channel = channel;
	newmap->dev_irq_aperture = 0;
	newmap->mask_info_cnt = 0;
	newmap->type = irq_type;
	newmap->entry = entry;

	/* Enable IRQ for this device in the kernel */
	if (request_irq(
			irq,
			&mods_irq_handle,
			(irq_type == MODS_IRQ_TYPE_INT) ? IRQF_SHARED : 0,
			nvdev->name,
			nvdev)) {
		mods_error_printk("unable to enable IRQ 0x%x\n", irq);
		kfree(newmap);
		LOG_EXT();
		return -EPERM;
	}

	/* Add the new entry to the list of all registered interrupts */
	list_add(&newmap->list, &pmp->irq_head[channel - 1]);

#ifdef CONFIG_PCI
	/* Map BAR0 to be able to disable interrupts */
	if ((irq_type == MODS_IRQ_TYPE_INT) &&
	    (p->aperture_addr != 0) &&
	    (p->aperture_size != 0)) {
		char *bar = ioremap_nocache(p->aperture_addr, p->aperture_size);

		if (!bar) {
			mods_debug_printk(DEBUG_ISR,
				"failed to remap aperture: 0x%llx size=0x%x\n",
				p->aperture_addr, p->aperture_size);
			LOG_EXT();
			return -EPERM;
		}

		newmap->dev_irq_aperture = bar;
		setup_mask_info(newmap, p, pdev);
	}
#endif

	/* Print out successful registration string */
	if (irq_type == MODS_IRQ_TYPE_CPU)
		mods_debug_printk(DEBUG_ISR, "registered CPU IRQ 0x%x\n", irq);
#ifdef CONFIG_PCI
	else if ((irq_type == MODS_IRQ_TYPE_INT) ||
		 (irq_type == MODS_IRQ_TYPE_MSI) ||
		 (irq_type == MODS_IRQ_TYPE_MSIX)) {
		mods_debug_printk(DEBUG_ISR,
		"%04x:%x:%02x.%x registered %s IRQ 0x%x\n",
		(unsigned int)(pci_domain_nr(pdev->bus)),
		(unsigned int)(pdev->bus->number),
		(unsigned int)PCI_SLOT(pdev->devfn),
		(unsigned int)PCI_FUNC(pdev->devfn),
		mods_irq_type_name(irq_type),
		  irq);
	}
#endif
#ifdef CONFIG_PCI_MSI
	else if (irq_type == MODS_IRQ_TYPE_MSI) {
		u16 control;
		u16 data;
		int cap_pos = pci_find_capability(pdev, PCI_CAP_ID_MSI);

		pci_read_config_word(pdev, MSI_CONTROL_REG(cap_pos), &control);
		if (IS_64BIT_ADDRESS(control))
			pci_read_config_word(pdev,
						 MSI_DATA_REG(cap_pos, 1),
						 &data);
		else
			pci_read_config_word(pdev,
						 MSI_DATA_REG(cap_pos, 0),
						 &data);
		mods_debug_printk(DEBUG_ISR,
			"%04x:%x:%02x.%x registered MSI IRQ 0x%x data:0x%02x\n",
			(unsigned int)(pci_domain_nr(pdev->bus)),
			(unsigned int)(pdev->bus->number),
			(unsigned int)PCI_SLOT(pdev->devfn),
			(unsigned int)PCI_FUNC(pdev->devfn),
			irq,
			(unsigned int)data);
	} else if (irq_type == MODS_IRQ_TYPE_MSIX) {
		mods_debug_printk(DEBUG_ISR,
			"%04x:%x:%02x.%x registered MSI-X IRQ 0x%x\n",
			(unsigned int)(pci_domain_nr(pdev->bus)),
			(unsigned int)(pdev->bus->number),
			(unsigned int)PCI_SLOT(pdev->devfn),
			(unsigned int)PCI_FUNC(pdev->devfn),
			irq);
	}
#endif

	LOG_EXT();
	return OK;
}

static void mods_free_map(struct dev_irq_map *del)
{
	LOG_ENT();

	/* Disable interrupts on the device */
	mods_disable_interrupts(del);

	/* Unmap aperture used for masking irqs */
	if (del->dev_irq_aperture)
		iounmap(del->dev_irq_aperture);

	/* Unhook interrupts in the kernel */
	free_irq(del->apic_irq, get_dev());

	/* Free memory */
	kfree(del);

	LOG_EXT();
}

void mods_init_irq(void)
{
	int i;
	struct mods_priv *pmp = get_all_data();

	LOG_ENT();

	memset(pmp, 0, sizeof(struct mods_priv));
	for (i = 0; i < MODS_CHANNEL_MAX; i++)
		INIT_LIST_HEAD(&pmp->irq_head[i]);

	spin_lock_init(&pmp->lock);
	LOG_EXT();
}

void mods_cleanup_irq(void)
{
	int i;
	struct mods_priv *pmp = get_all_data();

	LOG_ENT();
	for (i = 0; i < MODS_CHANNEL_MAX; i++) {
		if (pmp->channel_flags && (1 << i))
			mods_free_channel(i + 1);
	}
	LOG_EXT();
}

void mods_irq_dev_set_pri(unsigned char id, void *pri)
{
	struct nv_device *dev = get_dev();

	dev->pri[id - 1] = pri;
}

void mods_irq_dev_clr_pri(unsigned char id)
{
	struct nv_device *dev = get_dev();

	dev->pri[id - 1] = 0;
}

int mods_irq_event_check(unsigned char channel)
{
	struct mods_priv *pmp = get_all_data();
	struct irq_q_info *q = &pmp->rec_info[channel - 1];
	unsigned int pos = (1 << (channel - 1));

	if (!(pmp->channel_flags & pos))
		return POLLERR; /* irq has quit */

	if (q->head != q->tail)
		return POLLIN; /* irq generated */

	return 0;
}

unsigned char mods_alloc_channel(void)
{
	struct mods_priv *pmp = get_all_data();
	int i = 0;
	unsigned char channel = MODS_CHANNEL_MAX + 1;
	unsigned char max_channels = 1;

	LOG_ENT();

	if (mods_get_multi_instance() ||
	    (mods_get_access_token() != MODS_ACCESS_TOKEN_NONE))
		max_channels = MODS_CHANNEL_MAX;

	for (i = 0; i < max_channels; i++) {
		if (!test_and_set_bit(i, &pmp->channel_flags)) {
			channel = i + 1;
			mods_debug_printk(DEBUG_IOCTL,
					  "open channel %u (bit mask 0x%lx)\n",
					  (unsigned int)(i + 1),
					  pmp->channel_flags);
			break;
		}

	}

	LOG_EXT();
	return channel;
}

static int mods_free_irqs(unsigned char channel, struct pci_dev *dev)
{
#ifdef CONFIG_PCI
	struct mods_priv *pmp = get_all_data();
	struct dev_irq_map *del = NULL;
	struct dev_irq_map *next;
	struct en_dev_entry *dpriv = pci_get_drvdata(dev);
	unsigned int irq_type;

	LOG_ENT();

	if (!dpriv || !dpriv->irqs_allocated) {
		LOG_EXT();
		return OK;
	}

	mods_debug_printk(DEBUG_ISR_DETAILED,
		"(dev=%04x:%x:%02x.%x) irqs_allocated=%d irq_flags=0x%x nvecs=%d\n",
		pci_domain_nr(dev->bus),
		dev->bus->number,
		PCI_SLOT(dev->devfn),
		PCI_FUNC(dev->devfn),
		dpriv->irqs_allocated,
		dpriv->irq_flags,
		dpriv->nvecs
		);

	/* Delete device interrupts from the list */
	list_for_each_entry_safe(del, next, &pmp->irq_head[channel - 1], list) {
		if (dev == del->dev) {
			list_del(&del->list);
			mods_debug_printk(DEBUG_ISR,
				"%04x:%x:%02x.%x unregistered %s IRQ 0x%x\n",
				pci_domain_nr(dev->bus),
				dev->bus->number,
				PCI_SLOT(dev->devfn),
				PCI_FUNC(dev->devfn),
				mods_irq_type_name(del->type),
				del->apic_irq);
			mods_free_map(del);

			if (del->type != MODS_IRQ_TYPE_MSIX)
				break;
		}
	}

	mods_debug_printk(DEBUG_ISR_DETAILED, "before disable\n");
#ifdef CONFIG_PCI_MSI
	irq_type = MODS_IRQ_TYPE_FROM_FLAGS(dpriv->irq_flags);

	if (irq_type == MODS_IRQ_TYPE_MSIX) {
		pci_disable_msix(dev);
		kfree(dpriv->msix_entries);
	} else if (irq_type == MODS_IRQ_TYPE_MSI) {
		pci_disable_msi(dev);
	}
#endif

	dpriv->nvecs = 0;
	dpriv->msix_entries = NULL;
	dpriv->irqs_allocated = false;
	mods_debug_printk(DEBUG_ISR_DETAILED, "irqs freed\n");
#endif

	LOG_EXT();
	return 0;
}

void mods_free_channel(unsigned char channel)
{
	struct nv_device *nvdev = get_dev();
	MODS_PRIV priv = nvdev->pri[channel - 1];
	struct en_dev_entry *dent = priv->enabled_devices;
	struct mods_priv *pmp = get_all_data();
	struct irq_q_info *q = &pmp->rec_info[channel - 1];

	LOG_ENT();

	/* Release all interrupts */
	while (dent) {
		mods_free_irqs(priv->mods_id, dent->dev);
		dent = dent->next;
	}

	/* Clear queue */
	memset(q, 0, sizeof(*q));

	/* Indicate the channel is free */
	clear_bit(channel - 1, &pmp->channel_flags);

	mods_debug_printk(DEBUG_IOCTL, "closed channel %u\n",
			  (unsigned int)channel);
	LOG_EXT();
}

#ifdef CONFIG_PCI
static int mods_allocate_irqs(struct file *pfile, struct mods_pci_dev_2 *bdf,
				__u32 nvecs, __u32 flags)
{
	MODS_PRIV private_data = pfile->private_data;
	struct pci_dev *dev;
	struct en_dev_entry *dpriv;
	unsigned int devfn;
	unsigned int irq_type = MODS_IRQ_TYPE_FROM_FLAGS(flags);

	LOG_ENT();

	mods_debug_printk(DEBUG_ISR_DETAILED,
		"(dev=%04x:%x:%02x.%x, flags=0x%x, nvecs=%d)\n",
		(unsigned int)bdf->domain,
		(unsigned int)bdf->bus,
		(unsigned int)bdf->device,
		(unsigned int)bdf->function,
		flags,
		nvecs);

	if (!nvecs) {
		mods_error_printk("no irq's requested!\n");
		LOG_EXT();
		return -EINVAL;
	}

	/* Get the PCI device structure for the specified device from kernel */
	devfn = PCI_DEVFN(bdf->device, bdf->function);
	dev = MODS_PCI_GET_SLOT(bdf->domain, bdf->bus, devfn);
	if (!dev) {
		mods_error_printk(
				"unknown dev %04x:%x:%02x.%x\n",
				(unsigned int)bdf->domain,
				(unsigned int)bdf->bus,
				(unsigned int)bdf->device,
				(unsigned int)bdf->function);
		LOG_EXT();
		return -EINVAL;
	}

	/* Determine if the device supports requested interrupt type */
	if (irq_type == MODS_IRQ_TYPE_MSI) {
#ifdef CONFIG_PCI_MSI
		if (pci_find_capability(dev, PCI_CAP_ID_MSI) == 0) {
			mods_error_printk(
				"dev %04x:%x:%02x.%x does not support MSI\n",
				(unsigned int)bdf->domain,
				(unsigned int)bdf->bus,
				(unsigned int)bdf->device,
				(unsigned int)bdf->function);
			LOG_EXT();
			return -EINVAL;
		}
#else
		mods_error_printk("the kernel does not support MSI!\n");
		return -EINVAL;
#endif
	} else if (irq_type == MODS_IRQ_TYPE_MSIX) {
#ifdef CONFIG_PCI_MSI
		int msix_cap;

		msix_cap = pci_find_capability(dev, PCI_CAP_ID_MSIX);

		if (!msix_cap) {
			mods_error_printk(
				"dev %04x:%x:%02x.%x does not support MSI-X\n",
				(unsigned int)bdf->domain,
				(unsigned int)bdf->bus,
				(unsigned int)bdf->device,
				(unsigned int)bdf->function);
			LOG_EXT();
			return -EINVAL;
		}
#else
		mods_error_printk("the kernel does not support MSIX!\n");
		return -EINVAL;
#endif
	}

	/* Enable device on the PCI bus */
	if (mods_enable_device(private_data, dev)) {
		mods_error_printk("unable to enable dev %04x:%x:%02x.%x\n",
				  (unsigned int)bdf->domain,
				  (unsigned int)bdf->bus,
				  (unsigned int)bdf->device,
				  (unsigned int)bdf->function);
		LOG_EXT();
		return -EINVAL;
	}

	dpriv = pci_get_drvdata(dev);

	if (!dpriv) {
		mods_error_printk("could not get mods dev private!\n");
		LOG_EXT();
		return -EINVAL;
	}

	if (irq_type == MODS_IRQ_TYPE_INT) {
		/* use legacy irq */
		if (nvecs != 1) {
			mods_error_printk("INTA: only 1 INTA vector supported requested %d!\n",
				nvecs);
			LOG_EXT();
			return -EINVAL;
		}
		dpriv->nvecs = 1;
	}
	/* Enable MSI */
#ifdef CONFIG_PCI_MSI
	else if (irq_type == MODS_IRQ_TYPE_MSI) {
		if (nvecs != 1) {
			mods_error_printk("MSI: only 1 MSI vector supported requested %d!\n",
				nvecs);
			LOG_EXT();
			return -EINVAL;
		}
		if (pci_enable_msi(dev) != 0) {
			mods_error_printk(
				"unable to enable MSI on dev %04x:%x:%02x.%x\n",
				(unsigned int)bdf->domain,
				(unsigned int)bdf->bus,
				(unsigned int)bdf->device,
				(unsigned int)bdf->function);
			return -EINVAL;
		}
		dpriv->nvecs = 1;
	} else if (irq_type == MODS_IRQ_TYPE_MSIX) {
		struct msix_entry *entries;
		int i = 0, cnt = 1;

		entries = kcalloc(nvecs, sizeof(struct msix_entry),
				GFP_KERNEL | __GFP_NORETRY);

		if (!entries) {
			mods_error_printk("could not allocate %d MSI-X entries!\n",
				nvecs);
			LOG_EXT();
			return -ENOMEM;
		}

		for (i = 0; i < nvecs; i++)
			entries[i].entry = (uint16_t)i;

#ifdef MODS_HAS_MSIX_RANGE
		cnt = pci_enable_msix_range(dev, entries, nvecs, nvecs);

		if (cnt < 0) {
			/* returns number of interrupts allocated
			 * < 0 indicates a failure.
			 */
			mods_error_printk(
				"could not allocate the requested number of MSI-X vectors=%d return=%d!\n",
				nvecs, cnt);
			kfree(entries);
			LOG_EXT();
			return cnt;
		}
#else
		cnt = pci_enable_msix(dev, entries, nvecs);

		if (cnt) {
			/*  A return of < 0 indicates a failure.
			 *  A return of > 0 indicates that driver request is
			 *  exceeding the number of irqs or MSI-X
			 *  vectors available
			 */
			mods_error_printk(
				"could not allocate the requested number of MSI-X vectors=%d return=%d!\n",
				nvecs, cnt);
			kfree(entries);
			LOG_EXT();
			if (cnt > 0)
				cnt = -ENOSPC;
			return cnt;
		}
#endif

		mods_debug_printk(DEBUG_ISR,
			"allocated %d irq's of type %s(%d)\n",
			nvecs, mods_irq_type_name(irq_type), irq_type);

		for (i = 0; i < nvecs; i++)
			mods_debug_printk(DEBUG_ISR, "vec %d %x\n",
				entries[i].entry, entries[i].vector);

		dpriv->nvecs = nvecs;
		dpriv->msix_entries = entries;
	}
#endif
	else {
		mods_error_printk(
			"unsupported irq_type %d dev: %04x:%x:%02x.%x\n",
			irq_type,
				(unsigned int)bdf->domain,
				(unsigned int)bdf->bus,
				(unsigned int)bdf->device,
				(unsigned int)bdf->function);
			LOG_EXT();
			return -EINVAL;
	}

	dpriv->irqs_allocated = true;
	dpriv->irq_flags = flags;
	LOG_EXT();
	return OK;
}

static int mods_unregister_pci_irq(struct file *pfile,
				   struct MODS_REGISTER_IRQ_2 *p);

static int mods_register_pci_irq(struct file *pfile,
				 struct MODS_REGISTER_IRQ_4 *p)
{
	int rc = OK;
	unsigned int irq_type = MODS_IRQ_TYPE_FROM_FLAGS(p->irq_flags);
	struct pci_dev *dev;
	struct en_dev_entry *dpriv;
	unsigned int devfn;
	unsigned char channel;
	int i;

	LOG_ENT();

	/* Identify the caller */
	channel = MODS_GET_FILE_PRIVATE_ID(pfile);
	WARN_ON(id_is_valid(channel) != OK);
	if (id_is_valid(channel) != OK) {
		LOG_EXT();
		return -EINVAL;
	}

	/* Get the PCI device structure for the specified device from kernel */
	devfn = PCI_DEVFN(p->dev.device, p->dev.function);
	dev = MODS_PCI_GET_SLOT(p->dev.domain, p->dev.bus, devfn);
	if (!dev) {
		mods_error_printk(
				"unknown dev %04x:%x:%02x.%x\n",
				(unsigned int)p->dev.domain,
				(unsigned int)p->dev.bus,
				(unsigned int)p->dev.device,
				(unsigned int)p->dev.function);
		LOG_EXT();
		return -EINVAL;
	}

	dpriv = pci_get_drvdata(dev);

	if (!dpriv || !dpriv->irqs_allocated) {
		if (mods_allocate_irqs(pfile, &p->dev, p->irq_count,
			p->irq_flags)) {
			mods_error_printk(
			   "could not allocate irqs for irq_type %d\n",
				   irq_type);
			LOG_EXT();
			return -EINVAL;
		}
		dpriv = pci_get_drvdata(dev);
	} else {
		mods_error_printk(
			"dev %04x:%x:%02x.%x has already been registered\n",
			(unsigned int)p->dev.domain,
			(unsigned int)p->dev.bus,
			(unsigned int)p->dev.device,
			(unsigned int)p->dev.function);
		LOG_EXT();
		return -EINVAL;
	}

	for (i = 0; i < p->irq_count; i++) {
		u32 irq = ((irq_type == MODS_IRQ_TYPE_INT) ||
				(irq_type == MODS_IRQ_TYPE_MSI)) ? dev->irq :
			   dpriv->msix_entries[i].vector;

		if (add_irq_map(channel, dev, p, irq, i) != OK) {
#ifdef CONFIG_PCI_MSI
			if (irq_type == MODS_IRQ_TYPE_MSI)
				pci_disable_msi(dev);
			else if (irq_type == MODS_IRQ_TYPE_MSIX)
				pci_disable_msix(dev);
#endif
			LOG_EXT();
			return -EINVAL;
		}
	}

	LOG_EXT();
	return rc;
}
#endif /* CONFIG_PCI */

static int mods_register_cpu_irq(struct file *pfile,
				 struct MODS_REGISTER_IRQ_4 *p)
{
	unsigned char channel;
	u32 irq = p->dev.bus;

	LOG_ENT();

	/* Identify the caller */
	channel = MODS_GET_FILE_PRIVATE_ID(pfile);
	WARN_ON(id_is_valid(channel) != OK);
	if (id_is_valid(channel) != OK) {
		LOG_EXT();
		return -EINVAL;
	}

	/* Determine if the interrupt is already hooked */
	if (mods_lookup_irq(0, 0, irq) == IRQ_FOUND) {
		mods_error_printk("CPU IRQ 0x%x has already been registered\n",
				  irq);
		LOG_EXT();
		return -EINVAL;
	}

	/* Register interrupt */
	if (add_irq_map(channel, 0, p, irq, 0) != OK) {
		LOG_EXT();
		return -EINVAL;
	}

	return OK;
}

#ifdef CONFIG_PCI
static int mods_unregister_pci_irq(struct file *pfile,
				   struct MODS_REGISTER_IRQ_2 *p)
{
	struct pci_dev *dev;
	unsigned int devfn;
	unsigned char channel;
	int rv = OK;

	LOG_ENT();

	/* Identify the caller */
	channel = MODS_GET_FILE_PRIVATE_ID(pfile);
	WARN_ON(id_is_valid(channel) != OK);
	if (id_is_valid(channel) != OK) {
		LOG_EXT();
		return -EINVAL;
	}

	/* Get the PCI device structure for the specified device from kernel */
	devfn = PCI_DEVFN(p->dev.device, p->dev.function);
	dev = MODS_PCI_GET_SLOT(p->dev.domain, p->dev.bus, devfn);
	if (!dev) {
		LOG_EXT();
		return -EINVAL;
	}

	rv = mods_free_irqs(channel, dev);

	LOG_EXT();
	return rv;
}
#endif

static int mods_unregister_cpu_irq(struct file *pfile,
				   struct MODS_REGISTER_IRQ_2 *p)
{
	struct mods_priv *pmp = get_all_data();
	struct dev_irq_map *del = NULL;
	struct dev_irq_map *next;
	unsigned int irq;
	unsigned char channel;

	LOG_ENT();

	irq = p->dev.bus;

	/* Identify the caller */
	channel = MODS_GET_FILE_PRIVATE_ID(pfile);
	WARN_ON(id_is_valid(channel) != OK);
	if (id_is_valid(channel) != OK) {
		LOG_EXT();
		return -EINVAL;
	}

	/* Determine if the interrupt is already hooked by this client */
	if (mods_lookup_irq(channel, 0, irq) == IRQ_NOT_FOUND) {
		mods_error_printk(
			"IRQ 0x%x not hooked, can't unhook\n",
			irq);
		LOG_EXT();
		return -EINVAL;
	}

	/* Delete device interrupt from the list */
	list_for_each_entry_safe(del, next, &pmp->irq_head[channel - 1], list) {
		if ((irq == del->apic_irq) && (del->dev == 0)) {
			if (del->type != p->type) {
				mods_error_printk("wrong IRQ type passed\n");
				LOG_EXT();
				return -EINVAL;
			}
			list_del(&del->list);
			mods_debug_printk(DEBUG_ISR,
					  "unregistered CPU IRQ 0x%x\n",
					  irq);
			mods_free_map(del);
			break;
		}
	}

	LOG_EXT();
	return OK;
}

/*************************
 * ESCAPE CALL FUNCTIONS *
 *************************/

int esc_mods_register_irq_4(struct file *pfile,
			    struct MODS_REGISTER_IRQ_4 *p)
{
	u32 irq_type = MODS_IRQ_TYPE_FROM_FLAGS(p->irq_flags);

	if (irq_type == MODS_IRQ_TYPE_CPU)
		return mods_register_cpu_irq(pfile, p);
#ifdef CONFIG_PCI
	return mods_register_pci_irq(pfile, p);
#else
	mods_error_printk("PCI not available\n");
	return -EINVAL;
#endif
}

int esc_mods_register_irq_3(struct file *pfile,
			    struct MODS_REGISTER_IRQ_3 *p)
{
	struct MODS_REGISTER_IRQ_4 irq_data = { {0} };
	u32 ii = 0;

	irq_data.dev = p->dev;
	irq_data.aperture_addr = p->aperture_addr;
	irq_data.aperture_size = p->aperture_size;
	irq_data.mask_info_cnt = p->mask_info_cnt;
	for (ii = 0; ii < p->mask_info_cnt; ii++) {
		irq_data.mask_info[ii].mask_type = p->mask_info[ii].mask_type;
		irq_data.mask_info[ii].irq_pending_offset =
			p->mask_info[ii].irq_pending_offset;
		irq_data.mask_info[ii].irq_enabled_offset =
			p->mask_info[ii].irq_enabled_offset;
		irq_data.mask_info[ii].irq_enable_offset =
			p->mask_info[ii].irq_enable_offset;
		irq_data.mask_info[ii].irq_disable_offset =
			p->mask_info[ii].irq_disable_offset;
		irq_data.mask_info[ii].and_mask =
			p->mask_info[ii].and_mask;
		irq_data.mask_info[ii].or_mask =
			p->mask_info[ii].or_mask;
	}
	irq_data.irq_count = 1;
	irq_data.irq_flags = p->irq_type;

	return esc_mods_register_irq_4(pfile, &irq_data);
}

int esc_mods_register_irq_2(struct file *pfile,
			    struct MODS_REGISTER_IRQ_2 *p)
{
	struct MODS_REGISTER_IRQ_4 irq_data = { {0} };

	irq_data.dev = p->dev;
	irq_data.irq_count = 1;
	irq_data.irq_flags = p->type;
	if (p->type == MODS_IRQ_TYPE_CPU)
		return mods_register_cpu_irq(pfile, &irq_data);
#ifdef CONFIG_PCI
	{

	/* Get the PCI device structure for the specified device from kernel */
	unsigned int devfn;
	struct pci_dev *dev;

	devfn = PCI_DEVFN(p->dev.device, p->dev.function);
	dev  = MODS_PCI_GET_SLOT(p->dev.domain, p->dev.bus, devfn);
	if (!dev) {
		LOG_EXT();
		return -EINVAL;
	}
	/* initialize the new entry to behave like old implementation */
	irq_data.mask_info_cnt = 0;
	if ((p->type == MODS_IRQ_TYPE_INT) && is_nvidia_device(dev)) {
		irq_data.aperture_addr = pci_resource_start(dev, 0);
		irq_data.aperture_size = 0x200;
	}

	return mods_register_pci_irq(pfile, &irq_data);
	}
#else
	mods_error_printk("PCI not available\n");
	return -EINVAL;
#endif
}

int esc_mods_register_irq(struct file *pfile,
			  struct MODS_REGISTER_IRQ *p)
{
	struct MODS_REGISTER_IRQ_2 register_irq = { {0} };

	register_irq.dev.domain		= 0;
	register_irq.dev.bus		= p->dev.bus;
	register_irq.dev.device		= p->dev.device;
	register_irq.dev.function	= p->dev.function;
	register_irq.type		= p->type;

	return esc_mods_register_irq_2(pfile, &register_irq);
}

int esc_mods_unregister_irq_2(struct file *pfile,
				  struct MODS_REGISTER_IRQ_2 *p)
{
	if (p->type == MODS_IRQ_TYPE_CPU)
		return mods_unregister_cpu_irq(pfile, p);
#ifdef CONFIG_PCI
	return mods_unregister_pci_irq(pfile, p);
#else
	return -EINVAL;
#endif
}

int esc_mods_unregister_irq(struct file *pfile,
				struct MODS_REGISTER_IRQ *p)
{
	struct MODS_REGISTER_IRQ_2 register_irq = { {0} };

	register_irq.dev.domain		= 0;
	register_irq.dev.bus		= p->dev.bus;
	register_irq.dev.device		= p->dev.device;
	register_irq.dev.function	= p->dev.function;
	register_irq.type		= p->type;

	return esc_mods_unregister_irq_2(pfile, &register_irq);
}

int esc_mods_query_irq_3(struct file *pfile, struct MODS_QUERY_IRQ_3 *p)
{
	unsigned char channel;
	struct irq_q_info *q = NULL;
	struct mods_priv *pmp = get_all_data();
	unsigned int i = 0;
	unsigned long flags = 0;
	unsigned int cur_time = get_cur_time();

	/* Lock IRQ queue */
	LOG_ENT();
	spin_lock_irqsave(&pmp->lock, flags);

	/* Identify the caller */
	channel = MODS_GET_FILE_PRIVATE_ID(pfile);
	WARN_ON(id_is_valid(channel) != OK);
	if (id_is_valid(channel) != OK) {
		LOG_EXT();
		return -EINVAL;
	}

	/* Clear return array */
	memset(p->irq_list, 0xFF, sizeof(p->irq_list));

	/* Fill in return array with IRQ information */
	q = &pmp->rec_info[channel - 1];
	for (i = 0;
		 (q->head != q->tail) && (i < MODS_MAX_IRQS);
		 q->head++, i++) {

		unsigned int    index = q->head & (MODS_MAX_IRQS - 1);
		struct pci_dev *dev   = q->data[index].dev;

		if (dev) {
			p->irq_list[i].dev.domain = pci_domain_nr(dev->bus);
			p->irq_list[i].dev.bus = dev->bus->number;
			p->irq_list[i].dev.device = PCI_SLOT(dev->devfn);
			p->irq_list[i].dev.function = PCI_FUNC(dev->devfn);
		} else {
			p->irq_list[i].dev.domain = 0;
			p->irq_list[i].dev.bus = 0;
			p->irq_list[i].dev.device = 0xFFU;
			p->irq_list[i].dev.function = 0xFFU;
		}
		p->irq_list[i].irq_index = q->data[index].irq_index;
		p->irq_list[i].delay = cur_time - q->data[index].time;

		/* Print info about IRQ status returned */
		if (dev) {
			mods_debug_printk(DEBUG_ISR_DETAILED,
		   "retrieved IRQ index=%d dev %04x:%x:%02x.%x, time=%uus, delay=%uus\n",
				p->irq_list[i].irq_index,
				(unsigned int)p->irq_list[i].dev.domain,
				(unsigned int)p->irq_list[i].dev.bus,
				(unsigned int)p->irq_list[i].dev.device,
				(unsigned int)p->irq_list[i].dev.function,
				q->data[index].time,
				p->irq_list[i].delay);
		} else {
			mods_debug_printk(DEBUG_ISR_DETAILED,
				"retrieved IRQ 0x%x, time=%uus, delay=%uus\n",
				(unsigned int)p->irq_list[i].dev.bus,
				q->data[index].time,
				p->irq_list[i].delay);
		}
	}

	/* Indicate if there are more IRQs pending */
	if (q->head != q->tail)
		p->more = 1;

	/* Unlock IRQ queue */
	spin_unlock_irqrestore(&pmp->lock, flags);
	LOG_EXT();

	return OK;
}

int esc_mods_query_irq_2(struct file *pfile, struct MODS_QUERY_IRQ_2 *p)
{
	int retval, i;
	struct MODS_QUERY_IRQ_3 query_irq = { { { { 0 } } } };

	retval = esc_mods_query_irq_3(pfile, &query_irq);
	if (retval)
		return retval;

	for (i = 0; i < MODS_MAX_IRQS; i++) {
		p->irq_list[i].dev   = query_irq.irq_list[i].dev;
		p->irq_list[i].delay = query_irq.irq_list[i].delay;
	}
	p->more = query_irq.more;
	return OK;
}

int esc_mods_query_irq(struct file *pfile,
			   struct MODS_QUERY_IRQ *p)
{
	int retval, i;
	struct MODS_QUERY_IRQ_3 query_irq = { { { { 0 } } } };

	retval = esc_mods_query_irq_3(pfile, &query_irq);
	if (retval)
		return retval;

	for (i = 0; i < MODS_MAX_IRQS; i++) {
		p->irq_list[i].dev.bus    = query_irq.irq_list[i].dev.bus;
		p->irq_list[i].dev.device = query_irq.irq_list[i].dev.device;
		p->irq_list[i].dev.function
					  = query_irq.irq_list[i].dev.function;
		p->irq_list[i].delay	  = query_irq.irq_list[i].delay;
	}
	p->more = query_irq.more;
	return OK;
}

int esc_mods_set_irq_multimask(struct file *pfile,
				struct MODS_SET_IRQ_MULTIMASK *p)
{
	struct mods_priv *pmp = get_all_data();
	struct pci_dev *dev = 0;
	unsigned long flags = 0;
	unsigned char channel;
	u32 irq = ~0U;
	int ret = -EINVAL;
	int update_state_reg = 0;

	LOG_ENT();

	/* Identify the caller */
	channel = MODS_GET_FILE_PRIVATE_ID(pfile);
	WARN_ON(id_is_valid(channel) != OK);
	if (id_is_valid(channel) != OK) {
		LOG_EXT();
		return -EINVAL;
	}

	/* Print info */
	if (p->irq_type == MODS_IRQ_TYPE_CPU) {
		mods_debug_printk(
			DEBUG_ISR,
			"set CPU IRQ 0x%x mask &0x%llx |0x%llx addr=0x%llx\n",
			(unsigned int)p->dev.bus,
			p->mask_info[0].and_mask, p->mask_info[0].or_mask,
			p->aperture_addr + p->mask_info[0].reg_offset);
	} else {
		mods_debug_printk(
			DEBUG_ISR,
"set %s IRQ mask dev %04x:%x:%02x.%x mask t%d &0x%llx |0x%llx addr=0x%llx\n",
			mods_irq_type_name(p->irq_type),
			(unsigned int)p->dev.domain,
			(unsigned int)p->dev.bus,
			(unsigned int)p->dev.device,
			(unsigned int)p->dev.function,
			p->mask_info[0].mask_type,
			p->mask_info[0].and_mask,
			p->mask_info[0].or_mask,
			p->aperture_addr + p->mask_info[0].reg_offset);
	}

	/* Verify mask type */
	if (p->mask_info[0].mask_type != MODS_MASK_TYPE_IRQ_DISABLE &&
		p->mask_info[0].mask_type != MODS_MASK_TYPE_IRQ_DISABLE64) {
		mods_error_printk("invalid mask type\n");
		LOG_EXT();
		return -EINVAL;
	}

	/* Determine which interrupt is referenced */
	if (p->irq_type == MODS_IRQ_TYPE_CPU)
		irq = p->dev.bus;
	else if (p->irq_type == MODS_IRQ_TYPE_INT) {
#ifdef CONFIG_PCI
		/* Get the PCI dev struct for the specified device from kernel*/
		unsigned int devfn = PCI_DEVFN(p->dev.device, p->dev.function);

		dev = MODS_PCI_GET_SLOT(p->dev.domain, p->dev.bus, devfn);
		if (!dev) {
			LOG_EXT();
			return -EINVAL;
		}
		update_state_reg = is_nvidia_device(dev);
		if (!update_state_reg) {
			mods_error_printk(
			"set_irq_multimask is only supported GPUs!\n");
			LOG_EXT();
			return -EINVAL;
		}
#else
		mods_error_printk("PCI not available\n");
		LOG_EXT();
		return -EINVAL;
#endif
	} else {
		mods_error_printk("set_irq_multimask not supported for %s!\n",
			mods_irq_type_name(p->irq_type));
		LOG_EXT();
		return -EINVAL;
	}

	/* Lock IRQ queue */
	spin_lock_irqsave(&pmp->lock, flags);
	{
	struct dev_irq_map *t = NULL;
	struct dev_irq_map *next = NULL;
	struct irq_mask_info *im = NULL;
	struct mods_mask_info *mm = NULL;

	list_for_each_entry_safe(t, next, &pmp->irq_head[channel-1], list) {
		if ((dev && (t->dev == dev)) ||
		    (!dev && (t->apic_irq == irq))) {
			u32   i   = 0;
			char *bar = 0;

			if (t->type != p->irq_type) {
				mods_error_printk(
				"IRQ type does not match registered IRQ\n");
				break;
			}
			if (t->dev_irq_aperture) {
				iounmap(t->dev_irq_aperture);
				t->dev_irq_aperture = 0;
				t->mask_info_cnt = 0;
				t->mask_info[0].dev_irq_mask_reg = 0;
				t->mask_info[0].dev_irq_disable_reg = 0;
				t->mask_info[0].dev_irq_state = 0;
				mods_warning_printk("resetting IRQ mask\n");
			}
			bar = ioremap_nocache(p->aperture_addr,
					      p->aperture_size);
			if (!bar) {
				mods_error_printk(
				"unable to remap specified aperture\n");
				break;
			}

			t->dev_irq_aperture = bar;
			t->mask_info_cnt = p->mask_info_cnt;
			for (i = 0; i < p->mask_info_cnt; i++) {
				im = &t->mask_info[i];
				mm = &p->mask_info[i];
				im->dev_irq_disable_reg =
				    (u32 *)(bar + mm->reg_offset);
				im->dev_irq_mask_reg =
				    (u32 *)(bar + mm->reg_offset);
				im->irq_and_mask = mm->and_mask;
				im->irq_or_mask = mm->or_mask;
				im->mask_type = mm->mask_type;
				if (update_state_reg) {
					im->dev_irq_state =
					    (u32 *)(bar+0x100);
					im->dev_irq_mask_reg =
					    (u32 *)(bar+0x140);
				} else {
					im->dev_irq_state = 0;
					im->dev_irq_mask_reg = 0;
				}
			}
			ret = OK;
			break;
		}
	}
	}
	/* Unlock IRQ queue */
	spin_unlock_irqrestore(&pmp->lock, flags);
	LOG_EXT();

	return ret;
}

int esc_mods_set_irq_mask_2(struct file *pfile,
				struct MODS_SET_IRQ_MASK_2 *p)
{
	struct MODS_SET_IRQ_MULTIMASK set_irq_multimask = {0};

	set_irq_multimask.aperture_addr	= p->aperture_addr;
	set_irq_multimask.aperture_size	= p->aperture_size;
	set_irq_multimask.mask_info_cnt = 1;
	set_irq_multimask.mask_info[0].reg_offset = p->reg_offset;
	set_irq_multimask.mask_info[0].and_mask	  = p->and_mask;
	set_irq_multimask.mask_info[0].or_mask	  = p->or_mask;
	set_irq_multimask.mask_info[0].mask_type  = p->mask_type;
	set_irq_multimask.dev.domain	= p->dev.domain;
	set_irq_multimask.dev.bus	= p->dev.bus;
	set_irq_multimask.dev.device	= p->dev.device;
	set_irq_multimask.dev.function	= p->dev.function;
	set_irq_multimask.irq_type	= p->irq_type;

	return esc_mods_set_irq_multimask(pfile, &set_irq_multimask);
}

int esc_mods_set_irq_mask(struct file *pfile,
			  struct MODS_SET_IRQ_MASK *p)
{
	struct MODS_SET_IRQ_MULTIMASK set_irq_multimask = {0};

	set_irq_multimask.aperture_addr	= p->aperture_addr;
	set_irq_multimask.aperture_size	= p->aperture_size;
	set_irq_multimask.mask_info_cnt = 1;
	set_irq_multimask.mask_info[0].reg_offset	= p->reg_offset;
	set_irq_multimask.mask_info[0].and_mask		= p->and_mask;
	set_irq_multimask.mask_info[0].or_mask		= p->or_mask;
	set_irq_multimask.mask_info[0].mask_type	= p->mask_type;
	set_irq_multimask.dev.domain	= 0;
	set_irq_multimask.dev.bus	= p->dev.bus;
	set_irq_multimask.dev.device	= p->dev.device;
	set_irq_multimask.dev.function	= p->dev.function;
	set_irq_multimask.irq_type	= p->irq_type;

	return esc_mods_set_irq_multimask(pfile, &set_irq_multimask);
}

int esc_mods_irq_handled_2(struct file *pfile,
			   struct MODS_REGISTER_IRQ_2 *p)
{
	struct mods_priv *pmp = get_all_data();
	unsigned long flags = 0;
	unsigned char channel;
	u32 irq = p->dev.bus;
	struct dev_irq_map *t = NULL;
	struct dev_irq_map *next = NULL;
	int ret = -EINVAL;

	if (p->type != MODS_IRQ_TYPE_CPU)
		return -EINVAL;

	/* Lock IRQ queue */
	LOG_ENT();
	spin_lock_irqsave(&pmp->lock, flags);

	/* Identify the caller */
	channel = MODS_GET_FILE_PRIVATE_ID(pfile);
	WARN_ON(id_is_valid(channel) != OK);
	if (id_is_valid(channel) != OK) {
		LOG_EXT();
		return -EINVAL;
	}

	/* Print info */
	mods_debug_printk(DEBUG_ISR_DETAILED,
			  "mark CPU IRQ 0x%x handled\n", irq);

	list_for_each_entry_safe(t, next, &pmp->irq_head[channel-1], list) {
		if (t->apic_irq == irq) {
			if (t->type != p->type) {
				mods_error_printk(
				"IRQ type doesn't match registered IRQ\n");
			} else {
				enable_irq(irq);
				ret = OK;
			}
			break;
		}
	}

	/* Unlock IRQ queue */
	spin_unlock_irqrestore(&pmp->lock, flags);
	LOG_EXT();

	return ret;
}

int esc_mods_irq_handled(struct file *pfile,
			 struct MODS_REGISTER_IRQ *p)
{
	struct MODS_REGISTER_IRQ_2 register_irq = { {0} };

	register_irq.dev.domain		= 0;
	register_irq.dev.bus		= p->dev.bus;
	register_irq.dev.device		= p->dev.device;
	register_irq.dev.function	= p->dev.function;
	register_irq.type		= p->type;

	return esc_mods_irq_handled_2(pfile, &register_irq);
}

#if defined(MODS_TEGRA) && defined(CONFIG_OF_IRQ) && defined(CONFIG_OF)
int esc_mods_map_irq(struct file *pfile,
					 struct MODS_DT_INFO *p)
{
	int ret;
	/* the physical irq */
	int hwirq;
	/* platform device handle */
	struct platform_device *pdev = NULL;
	/* irq parameters */
	struct of_phandle_args oirq;
	/* Search for the node by device tree name */
	struct device_node *np = of_find_node_by_name(NULL, p->dt_name);

	/* Can be multiple nodes that share the same dt name, */
	/* make sure you get the correct node matched by the device's full */
	/* name in device tree (i.e. watchdog@30c0000 as opposed */
	/* to watchdog) */
	while (of_node_cmp(np->full_name, p->full_name) != 0)
		np = of_find_node_by_name(np, p->dt_name);

	p->irq = irq_of_parse_and_map(np, p->index);
	ret = of_irq_parse_one(np, p->index, &oirq);
	if (ret) {
		mods_error_printk("Could not parse IRQ\n");
		return -EINVAL;
	}

	hwirq = oirq.args[1];
	/* Get the platform device handle */
	pdev = of_find_device_by_node(np);

	if (of_node_cmp(p->dt_name, "watchdog") == 0) {
		/* Enable and unmask interrupt for watchdog */
		struct resource *res_src = platform_get_resource(pdev,
		IORESOURCE_MEM, 0);
		struct resource *res_tke = platform_get_resource(pdev,
		IORESOURCE_MEM, 2);
		void __iomem *wdt_tke = devm_ioremap(&pdev->dev,
		res_tke->start, resource_size(res_tke));
		int wdt_index = ((res_src->start >> 16) & 0xF) - 0xc;

		writel(TOP_TKE_TKEIE_WDT_MASK(wdt_index), wdt_tke +
		TOP_TKE_TKEIE(hwirq));
	}

	/* enable the interrupt */
	return 0;

}
#endif
