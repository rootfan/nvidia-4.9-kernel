/*
 * drivers/video/tegra/nvmap/nvmap_alloc.c
 *
 * Handle allocation and freeing routines for nvmap
 *
 * Copyright (c) 2011-2017, NVIDIA CORPORATION. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 */

#define pr_fmt(fmt)	"%s: " fmt, __func__

#include <linux/moduleparam.h>

#include <trace/events/nvmap.h>

#include "nvmap_priv.h"

bool nvmap_convert_carveout_to_iovmm;
bool nvmap_convert_iovmm_to_carveout;

u32 nvmap_max_handle_count;
u64 nvmap_big_page_allocs;
u64 nvmap_total_page_allocs;

/* handles may be arbitrarily large (16+MiB), and any handle allocated from
 * the kernel (i.e., not a carveout handle) includes its array of pages. to
 * preserve kmalloc space, if the array of pages exceeds PAGELIST_VMALLOC_MIN,
 * the array is allocated using vmalloc. */
#define PAGELIST_VMALLOC_MIN	(PAGE_SIZE)

void *nvmap_altalloc(size_t len)
{
	if (len > PAGELIST_VMALLOC_MIN)
		return vmalloc(len);
	else
		return kmalloc(len, GFP_KERNEL);
}

void nvmap_altfree(void *ptr, size_t len)
{
	if (!ptr)
		return;

	if (len > PAGELIST_VMALLOC_MIN)
		vfree(ptr);
	else
		kfree(ptr);
}

static struct page *nvmap_alloc_pages_exact(gfp_t gfp, size_t size)
{
	struct page *page, *p, *e;
	unsigned int order;

	order = get_order(size);
	page = alloc_pages(gfp, order);

	if (!page)
		return NULL;

	split_page(page, order);
	e = nth_page(page, (1 << order));
	for (p = nth_page(page, (size >> PAGE_SHIFT)); p < e; p++)
		__free_page(p);

	return page;
}

static int handle_page_alloc(struct nvmap_client *client,
			     struct nvmap_handle *h, bool contiguous)
{
	size_t size = h->size;
	int nr_page = size >> PAGE_SHIFT;
	int i = 0, page_index = 0;
	struct page **pages;
	gfp_t gfp = GFP_NVMAP | __GFP_ZERO;
	int pages_per_big_pg = NVMAP_PP_BIG_PAGE_SIZE >> PAGE_SHIFT;

	pages = nvmap_altalloc(nr_page * sizeof(*pages));
	if (!pages)
		return -ENOMEM;

	if (contiguous) {
		struct page *page;
		page = nvmap_alloc_pages_exact(gfp, size);
		if (!page)
			goto fail;

		for (i = 0; i < nr_page; i++)
			pages[i] = nth_page(page, i);

	} else {
#ifdef CONFIG_NVMAP_PAGE_POOLS
		/* Get as many big pages from the pool as possible. */
		page_index = nvmap_page_pool_alloc_lots_bp(&nvmap_dev->pool, pages,
								 nr_page);
		pages_per_big_pg = nvmap_dev->pool.pages_per_big_pg;
#endif
		/* Try to allocate big pages from page allocator */
		for (i = page_index;
		     i < nr_page && pages_per_big_pg > 1 && (nr_page - i) >= pages_per_big_pg;
		     i += pages_per_big_pg, page_index += pages_per_big_pg) {
			struct page *page;
			int idx;
			/*
			 * set the gfp not to trigger direct/kswapd reclaims and
			 * not to use emergency reserves.
			 */
			gfp_t gfp_no_reclaim = (gfp | __GFP_NOMEMALLOC) & ~__GFP_RECLAIM;

			page = nvmap_alloc_pages_exact(gfp_no_reclaim,
					pages_per_big_pg << PAGE_SHIFT);
			if (!page)
				break;

			for (idx = 0; idx < pages_per_big_pg; idx++)
				pages[i + idx] = nth_page(page, idx);
			nvmap_clean_cache(&pages[i], pages_per_big_pg);
		}
		nvmap_big_page_allocs += page_index;

#ifdef CONFIG_NVMAP_PAGE_POOLS
		/* Get as many 4K pages from the pool as possible. */
		page_index += nvmap_page_pool_alloc_lots(&nvmap_dev->pool, &pages[page_index],
								 nr_page - page_index);
#endif

		for (i = page_index; i < nr_page; i++) {
			pages[i] = nvmap_alloc_pages_exact(gfp, PAGE_SIZE);
			if (!pages[i])
				goto fail;
		}
		nvmap_total_page_allocs += nr_page;
	}

	/*
	 * Make sure any data in the caches is cleaned out before
	 * passing these pages to userspace. Many nvmap clients assume that
	 * the buffers are clean as soon as they are allocated. nvmap
	 * clients can pass the buffer to hardware as it is without any
	 * explicit cache maintenance.
	 */
	if (page_index < nr_page)
		nvmap_clean_cache(&pages[page_index], nr_page - page_index);

	h->pgalloc.pages = pages;
	h->pgalloc.contig = contiguous;
	atomic_set(&h->pgalloc.ndirty, 0);
	return 0;

fail:
	while (i--)
		__free_page(pages[i]);
	nvmap_altfree(pages, nr_page * sizeof(*pages));
	wmb();
	return -ENOMEM;
}

static struct device *nvmap_heap_pgalloc_dev(unsigned long type)
{
	int ret = -EINVAL;
	struct device *dma_dev;

#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 4, 0)
	ret = 0;
#endif

	if (ret || (type != NVMAP_HEAP_CARVEOUT_VPR))
		return ERR_PTR(-EINVAL);

	dma_dev = dma_dev_from_handle(type);
	if (IS_ERR(dma_dev))
		return dma_dev;

	ret = dma_set_resizable_heap_floor_size(dma_dev, 0);
	if (ret)
		return ERR_PTR(ret);
	return dma_dev;
}

static int nvmap_heap_pgalloc(struct nvmap_client *client,
			struct nvmap_handle *h, unsigned long type)
{
	size_t size = h->size;
	struct page **pages;
	struct device *dma_dev;
	DEFINE_DMA_ATTRS(attrs);
	dma_addr_t pa;

	dma_dev = nvmap_heap_pgalloc_dev(type);
	if (IS_ERR(dma_dev))
		return PTR_ERR(dma_dev);

	dma_set_attr(DMA_ATTR_ALLOC_EXACT_SIZE, __DMA_ATTR(attrs));
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 4, 0)
	dma_set_attr(DMA_ATTR_ALLOC_SINGLE_PAGES, __DMA_ATTR(attrs));
#endif

	pages = dma_alloc_attrs(dma_dev, size, &pa,
			GFP_KERNEL, __DMA_ATTR(attrs));
	if (dma_mapping_error(dma_dev, pa))
		return -ENOMEM;

	h->pgalloc.pages = pages;
	h->pgalloc.contig = 0;
	atomic_set(&h->pgalloc.ndirty, 0);
	return 0;
}

static int nvmap_heap_pgfree(struct nvmap_handle *h)
{
	size_t size = h->size;
	struct device *dma_dev;
	DEFINE_DMA_ATTRS(attrs);
	dma_addr_t pa = ~(dma_addr_t)0;

	dma_dev = nvmap_heap_pgalloc_dev(h->heap_type);
	if (IS_ERR(dma_dev))
		return PTR_ERR(dma_dev);

	dma_set_attr(DMA_ATTR_ALLOC_EXACT_SIZE, __DMA_ATTR(attrs));
#if LINUX_VERSION_CODE >= KERNEL_VERSION(4, 4, 0)
	dma_set_attr(DMA_ATTR_ALLOC_SINGLE_PAGES, __DMA_ATTR(attrs));
#endif

	dma_free_attrs(dma_dev, size, h->pgalloc.pages, pa,
		       __DMA_ATTR(attrs));

	h->pgalloc.pages = NULL;
	return 0;
}
static void alloc_handle(struct nvmap_client *client,
			 struct nvmap_handle *h, unsigned int type)
{
	unsigned int carveout_mask = NVMAP_HEAP_CARVEOUT_MASK;
	unsigned int iovmm_mask = NVMAP_HEAP_IOVMM;
	int ret;

	BUG_ON(type & (type - 1));

	if (nvmap_convert_carveout_to_iovmm) {
		carveout_mask &= ~NVMAP_HEAP_CARVEOUT_GENERIC;
		iovmm_mask |= NVMAP_HEAP_CARVEOUT_GENERIC;
	} else if (nvmap_convert_iovmm_to_carveout) {
		if (type & NVMAP_HEAP_IOVMM) {
			type &= ~NVMAP_HEAP_IOVMM;
			type |= NVMAP_HEAP_CARVEOUT_GENERIC;
		}
	}

	if (type & carveout_mask) {
		struct nvmap_heap_block *b;

		b = nvmap_carveout_alloc(client, h, type, NULL);
		if (b) {
			h->heap_type = type;
			h->heap_pgalloc = false;
			/* barrier to ensure all handle alloc data
			 * is visible before alloc is seen by other
			 * processors.
			 */
			mb();
			h->alloc = true;
			return;
		}
		ret = nvmap_heap_pgalloc(client, h, type);
		if (ret)
			return;
		h->heap_type = NVMAP_HEAP_CARVEOUT_VPR;
		h->heap_pgalloc = true;
		mb();
		h->alloc = true;
	} else if (type & iovmm_mask) {
		ret = handle_page_alloc(client, h,
			h->userflags & NVMAP_HANDLE_PHYS_CONTIG);
		if (ret)
			return;
		h->heap_type = NVMAP_HEAP_IOVMM;
		h->heap_pgalloc = true;
		mb();
		h->alloc = true;
	}
}

static int alloc_handle_from_va(struct nvmap_client *client,
				 struct nvmap_handle *h,
				 ulong vaddr)
{
	int nr_page = h->size >> PAGE_SHIFT;
	struct page **pages;
	int ret = 0;

	pages = nvmap_altalloc(nr_page * sizeof(*pages));
	if (IS_ERR_OR_NULL(pages))
		return PTR_ERR(pages);

	ret = nvmap_get_user_pages(vaddr & PAGE_MASK, nr_page, pages);
	if (ret) {
		nvmap_altfree(pages, nr_page * sizeof(*pages));
		return ret;
	}

	nvmap_clean_cache(&pages[0], nr_page);
	h->pgalloc.pages = pages;
	atomic_set(&h->pgalloc.ndirty, 0);
	h->heap_type = NVMAP_HEAP_IOVMM;
	h->heap_pgalloc = true;
	h->from_va = true;
	mb();
	h->alloc = true;
	return ret;
}

/* small allocations will try to allocate from generic OS memory before
 * any of the limited heaps, to increase the effective memory for graphics
 * allocations, and to reduce fragmentation of the graphics heaps with
 * sub-page splinters */
static const unsigned int heap_policy_small[] = {
	NVMAP_HEAP_CARVEOUT_VPR,
	NVMAP_HEAP_CARVEOUT_IRAM,
	NVMAP_HEAP_CARVEOUT_MASK,
	NVMAP_HEAP_IOVMM,
	0,
};

static const unsigned int heap_policy_large[] = {
	NVMAP_HEAP_CARVEOUT_VPR,
	NVMAP_HEAP_CARVEOUT_IRAM,
	NVMAP_HEAP_IOVMM,
	NVMAP_HEAP_CARVEOUT_MASK,
	0,
};

static const unsigned int heap_policy_excl[] = {
	NVMAP_HEAP_CARVEOUT_IVM,
	NVMAP_HEAP_CARVEOUT_VIDMEM,
	0,
};

int nvmap_alloc_handle(struct nvmap_client *client,
		       struct nvmap_handle *h, unsigned int heap_mask,
		       size_t align,
		       u8 kind,
		       unsigned int flags,
		       int peer)
{
	const unsigned int *alloc_policy;
	int nr_page;
	int err = -ENOMEM;
	int tag, i;
	bool alloc_from_excl = false;

	h = nvmap_handle_get(h);

	if (!h)
		return -EINVAL;

	if (h->alloc) {
		nvmap_handle_put(h);
		return -EEXIST;
	}

	nvmap_stats_inc(NS_TOTAL, h->size);
	nvmap_stats_inc(NS_ALLOC, h->size);
	trace_nvmap_alloc_handle(client, h,
		h->size, heap_mask, align, flags,
		nvmap_stats_read(NS_TOTAL),
		nvmap_stats_read(NS_ALLOC));
	h->userflags = flags;
	nr_page = ((h->size + PAGE_SIZE - 1) >> PAGE_SHIFT);
	/* Force mapping to uncached for VPR memory. */
	if (heap_mask & (NVMAP_HEAP_CARVEOUT_VPR | ~nvmap_dev->cpu_access_mask))
		h->flags = NVMAP_HANDLE_UNCACHEABLE;
	else
		h->flags = (flags & NVMAP_HANDLE_CACHE_FLAG);
	h->align = max_t(size_t, align, L1_CACHE_BYTES);
	h->peer = peer;
	tag = flags >> 16;

	if (!tag && client && !client->tag_warned) {
		char task_comm[TASK_COMM_LEN];
		client->tag_warned = 1;
		get_task_comm(task_comm, client->task);
		pr_err("PID %d: %s: WARNING: "
			"All NvMap Allocations must have a tag "
			"to identify the subsystem allocating memory."
			"Please pass the tag to the API call"
			" NvRmMemHanldeAllocAttr() or relevant. \n",
			client->task->pid, task_comm);
	}

	/*
	 * If user specifies one of the exclusive carveouts, allocation
	 * from no other heap should be allowed.
	 */
	for (i = 0; i < ARRAY_SIZE(heap_policy_excl); i++) {
		if (!(heap_mask & heap_policy_excl[i]))
			continue;

		if (heap_mask & ~(heap_policy_excl[i])) {
			pr_err("%s alloc mixes exclusive heap %d and other heaps\n",
			       current->group_leader->comm, heap_policy_excl[i]);
			err = -EINVAL;
			goto out;
		}
		alloc_from_excl = true;
	}

	if (!heap_mask) {
		err = -EINVAL;
		goto out;
	}

	alloc_policy = alloc_from_excl ? heap_policy_excl :
			(nr_page == 1) ? heap_policy_small : heap_policy_large;

	while (!h->alloc && *alloc_policy) {
		unsigned int heap_type;

		heap_type = *alloc_policy++;
		heap_type &= heap_mask;

		if (!heap_type)
			continue;

		heap_mask &= ~heap_type;

		while (heap_type && !h->alloc) {
			unsigned int heap;

			/* iterate possible heaps MSB-to-LSB, since higher-
			 * priority carveouts will have higher usage masks */
			heap = 1 << __fls(heap_type);
			alloc_handle(client, h, heap);
			heap_type &= ~heap;
		}
	}

out:
	if (h->alloc) {
		if (client->kernel_client)
			nvmap_stats_inc(NS_KALLOC, h->size);
		else
			nvmap_stats_inc(NS_UALLOC, h->size);
		NVMAP_TAG_TRACE(trace_nvmap_alloc_handle_done,
			NVMAP_TP_ARGS_CHR(client, h, NULL));
		err = 0;
	} else {
		nvmap_stats_dec(NS_TOTAL, h->size);
		nvmap_stats_dec(NS_ALLOC, h->size);
	}
	nvmap_handle_put(h);
	return err;
}

int nvmap_alloc_handle_from_va(struct nvmap_client *client,
			       struct nvmap_handle *h,
			       ulong addr,
			       unsigned int flags)
{
	int err = -ENOMEM;
	int tag;

	h = nvmap_handle_get(h);
	if (!h)
		return -EINVAL;

	if (h->alloc) {
		nvmap_handle_put(h);
		return -EEXIST;
	}

	h->userflags = flags;
	h->flags = (flags & NVMAP_HANDLE_CACHE_FLAG);
	h->align = PAGE_SIZE;
	tag = flags >> 16;

	if (!tag && client && !client->tag_warned) {
		char task_comm[TASK_COMM_LEN];
		client->tag_warned = 1;
		get_task_comm(task_comm, client->task);
		pr_err("PID %d: %s: WARNING: "
			"All NvMap Allocations must have a tag "
			"to identify the subsystem allocating memory."
			"Please pass the tag to the API call"
			" NvRmMemHanldeAllocAttr() or relevant. \n",
			client->task->pid, task_comm);
	}

	(void)alloc_handle_from_va(client, h, addr);

	if (h->alloc) {
		NVMAP_TAG_TRACE(trace_nvmap_alloc_handle_done,
			NVMAP_TP_ARGS_CHR(client, h, NULL));
		err = 0;
	}
	nvmap_handle_put(h);
	return err;
}

void _nvmap_handle_free(struct nvmap_handle *h)
{
	unsigned int i, nr_page, page_index = 0;
	struct nvmap_handle_dmabuf_priv *curr, *next;

	list_for_each_entry_safe(curr, next, &h->dmabuf_priv, list) {
		curr->priv_release(curr->priv);
		list_del(&curr->list);
		kzfree(curr);
	}

	if (nvmap_handle_remove(nvmap_dev, h) != 0)
		return;

	if (!h->alloc)
		goto out;

	nvmap_stats_inc(NS_RELEASE, h->size);
	nvmap_stats_dec(NS_TOTAL, h->size);
	if (!h->heap_pgalloc) {
		if (h->vaddr) {
			struct vm_struct *vm;
			void *addr = h->vaddr;

			addr -= (h->carveout->base & ~PAGE_MASK);
			vm = find_vm_area(addr);
			BUG_ON(!vm);
			free_vm_area(vm);
		}

		nvmap_heap_free(h->carveout);
		nvmap_kmaps_dec(h);
		h->vaddr = NULL;
		goto out;
	} else {
		int ret = nvmap_heap_pgfree(h);
		if (!ret)
			goto out;
	}

	nr_page = DIV_ROUND_UP(h->size, PAGE_SIZE);

	BUG_ON(h->size & ~PAGE_MASK);
	BUG_ON(!h->pgalloc.pages);

	if (h->vaddr) {
		nvmap_kmaps_dec(h);

		vm_unmap_ram(h->vaddr, h->size >> PAGE_SHIFT);
		h->vaddr = NULL;
	}

	for (i = 0; i < nr_page; i++)
		h->pgalloc.pages[i] = nvmap_to_page(h->pgalloc.pages[i]);

#ifdef CONFIG_NVMAP_PAGE_POOLS
	if (!h->from_va)
		page_index = nvmap_page_pool_fill_lots(&nvmap_dev->pool,
					h->pgalloc.pages, nr_page);
#endif

	for (i = page_index; i < nr_page; i++) {
		if (h->from_va)
			put_page(h->pgalloc.pages[i]);
		else
			__free_page(h->pgalloc.pages[i]);
	}

	nvmap_altfree(h->pgalloc.pages, nr_page * sizeof(struct page *));

out:
	NVMAP_TAG_TRACE(trace_nvmap_destroy_handle,
		NULL, get_current()->pid, 0, NVMAP_TP_ARGS_H(h));
	kfree(h);
}

void nvmap_free_handle(struct nvmap_client *client,
		       struct nvmap_handle *handle)
{
	struct nvmap_handle_ref *ref;
	struct nvmap_handle *h;

	nvmap_ref_lock(client);

	ref = __nvmap_validate_locked(client, handle);
	if (!ref) {
		nvmap_ref_unlock(client);
		return;
	}

	BUG_ON(!ref->handle);
	h = ref->handle;

	if (atomic_dec_return(&ref->dupes)) {
		NVMAP_TAG_TRACE(trace_nvmap_free_handle,
			NVMAP_TP_ARGS_CHR(client, h, ref));
		nvmap_ref_unlock(client);
		goto out;
	}

	smp_rmb();
	rb_erase(&ref->node, &client->handle_refs);
	client->handle_count--;
	atomic_dec(&ref->handle->share_count);

	nvmap_ref_unlock(client);

	if (h->owner == client)
		h->owner = NULL;

	dma_buf_put(ref->handle->dmabuf);
	NVMAP_TAG_TRACE(trace_nvmap_free_handle,
		NVMAP_TP_ARGS_CHR(client, h, ref));
	kfree(ref);

out:
	BUG_ON(!atomic_read(&h->ref));
	nvmap_handle_put(h);
}
EXPORT_SYMBOL(nvmap_free_handle);

void nvmap_free_handle_fd(struct nvmap_client *client,
			       int fd)
{
	struct nvmap_handle *handle = nvmap_handle_get_from_fd(fd);
	if (handle) {
		nvmap_free_handle(client, handle);
		nvmap_handle_put(handle);
	}
}
