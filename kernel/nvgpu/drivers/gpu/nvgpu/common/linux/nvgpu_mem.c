/*
 * Copyright (c) 2017-2018, NVIDIA CORPORATION.  All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <nvgpu/dma.h>
#include <nvgpu/gmmu.h>
#include <nvgpu/nvgpu_mem.h>
#include <nvgpu/page_allocator.h>
#include <nvgpu/log.h>
#include <nvgpu/bug.h>
#include <nvgpu/enabled.h>
#include <nvgpu/kmem.h>
#include <nvgpu/vidmem.h>

#include <nvgpu/linux/dma.h>
#include <nvgpu/linux/vidmem.h>

#include <linux/vmalloc.h>

#include "os_linux.h"

#include "gk20a/gk20a.h"
#include "gk20a/mm_gk20a.h"
#include "platform_gk20a.h"

static u64 __nvgpu_sgl_phys(struct gk20a *g, struct nvgpu_sgl *sgl)
{
	struct device *dev = dev_from_gk20a(g);
	struct gk20a_platform *platform = gk20a_get_platform(dev);
	u64 ipa = sg_phys((struct scatterlist *)sgl);

	if (platform->phys_addr)
		return platform->phys_addr(g, ipa);

	return ipa;
}

int nvgpu_mem_begin(struct gk20a *g, struct nvgpu_mem *mem)
{
	void *cpu_va;
	pgprot_t prot = nvgpu_is_enabled(g, NVGPU_USE_COHERENT_SYSMEM) ?
		PAGE_KERNEL :
		pgprot_writecombine(PAGE_KERNEL);

	if (mem->aperture != APERTURE_SYSMEM)
		return 0;

	/*
	 * WAR for bug 2040115: we already will always have a coherent vmap()
	 * for all sysmem buffers. The prot settings are left alone since
	 * eventually this should be deleted.
	 */
	if (nvgpu_is_enabled(g, NVGPU_USE_COHERENT_SYSMEM))
		return 0;

	/*
	 * A CPU mapping is implicitly made for all SYSMEM DMA allocations that
	 * don't have NVGPU_DMA_NO_KERNEL_MAPPING. Thus we don't need to make
	 * another CPU mapping.
	 */
	if (!(mem->priv.flags & NVGPU_DMA_NO_KERNEL_MAPPING))
		return 0;

	if (WARN_ON(mem->cpu_va)) {
		nvgpu_warn(g, "nested");
		return -EBUSY;
	}

	cpu_va = vmap(mem->priv.pages,
			PAGE_ALIGN(mem->size) >> PAGE_SHIFT,
			0, prot);

	if (WARN_ON(!cpu_va))
		return -ENOMEM;

	mem->cpu_va = cpu_va;
	return 0;
}

void nvgpu_mem_end(struct gk20a *g, struct nvgpu_mem *mem)
{
	if (mem->aperture != APERTURE_SYSMEM)
		return;

	/*
	 * WAR for bug 2040115: skip this since the map will be taken care of
	 * during the free in the DMA API.
	 */
	if (nvgpu_is_enabled(g, NVGPU_USE_COHERENT_SYSMEM))
		return;

	/*
	 * Similar to nvgpu_mem_begin() we don't need to unmap the CPU mapping
	 * already made by the DMA API.
	 */
	if (!(mem->priv.flags & NVGPU_DMA_NO_KERNEL_MAPPING))
		return;

	vunmap(mem->cpu_va);
	mem->cpu_va = NULL;
}

static void pramin_access_batch_rd_n(struct gk20a *g, u32 start, u32 words, u32 **arg)
{
	struct nvgpu_os_linux *l = nvgpu_os_linux_from_gk20a(g);
	u32 r = start, *dest_u32 = *arg;

	if (!l->regs) {
		__gk20a_warn_on_no_regs();
		return;
	}

	while (words--) {
		*dest_u32++ = gk20a_readl(g, r);
		r += sizeof(u32);
	}

	*arg = dest_u32;
}

u32 nvgpu_mem_rd32(struct gk20a *g, struct nvgpu_mem *mem, u32 w)
{
	u32 data = 0;

	if (mem->aperture == APERTURE_SYSMEM) {
		u32 *ptr = mem->cpu_va;

		WARN_ON(!ptr);
		data = ptr[w];
#ifdef CONFIG_TEGRA_SIMULATION_PLATFORM
		nvgpu_log(g, gpu_dbg_mem, " %p = 0x%x", ptr + w, data);
#endif
	} else if (mem->aperture == APERTURE_VIDMEM) {
		u32 value;
		u32 *p = &value;

		nvgpu_pramin_access_batched(g, mem, w * sizeof(u32),
				sizeof(u32), pramin_access_batch_rd_n, &p);

		data = value;

	} else {
		WARN_ON("Accessing unallocated nvgpu_mem");
	}

	return data;
}

u32 nvgpu_mem_rd(struct gk20a *g, struct nvgpu_mem *mem, u32 offset)
{
	WARN_ON(offset & 3);
	return nvgpu_mem_rd32(g, mem, offset / sizeof(u32));
}

void nvgpu_mem_rd_n(struct gk20a *g, struct nvgpu_mem *mem,
		u32 offset, void *dest, u32 size)
{
	WARN_ON(offset & 3);
	WARN_ON(size & 3);

	if (mem->aperture == APERTURE_SYSMEM) {
		u8 *src = (u8 *)mem->cpu_va + offset;

		WARN_ON(!mem->cpu_va);
		memcpy(dest, src, size);
#ifdef CONFIG_TEGRA_SIMULATION_PLATFORM
		if (size)
			nvgpu_log(g, gpu_dbg_mem, " %p = 0x%x ... [%d bytes]",
					src, *dest, size);
#endif
	} else if (mem->aperture == APERTURE_VIDMEM) {
		u32 *dest_u32 = dest;

		nvgpu_pramin_access_batched(g, mem, offset, size,
				pramin_access_batch_rd_n, &dest_u32);
	} else {
		WARN_ON("Accessing unallocated nvgpu_mem");
	}
}

static void pramin_access_batch_wr_n(struct gk20a *g, u32 start, u32 words, u32 **arg)
{
	struct nvgpu_os_linux *l = nvgpu_os_linux_from_gk20a(g);
	u32 r = start, *src_u32 = *arg;

	if (!l->regs) {
		__gk20a_warn_on_no_regs();
		return;
	}

	while (words--) {
		writel_relaxed(*src_u32++, l->regs + r);
		r += sizeof(u32);
	}

	*arg = src_u32;
}

void nvgpu_mem_wr32(struct gk20a *g, struct nvgpu_mem *mem, u32 w, u32 data)
{
	if (mem->aperture == APERTURE_SYSMEM) {
		u32 *ptr = mem->cpu_va;

		WARN_ON(!ptr);
#ifdef CONFIG_TEGRA_SIMULATION_PLATFORM
		nvgpu_log(g, gpu_dbg_mem, " %p = 0x%x", ptr + w, data);
#endif
		ptr[w] = data;
	} else if (mem->aperture == APERTURE_VIDMEM) {
		u32 value = data;
		u32 *p = &value;

		nvgpu_pramin_access_batched(g, mem, w * sizeof(u32),
				sizeof(u32), pramin_access_batch_wr_n, &p);
		if (!mem->skip_wmb)
			wmb();
	} else {
		WARN_ON("Accessing unallocated nvgpu_mem");
	}
}

void nvgpu_mem_wr(struct gk20a *g, struct nvgpu_mem *mem, u32 offset, u32 data)
{
	WARN_ON(offset & 3);
	nvgpu_mem_wr32(g, mem, offset / sizeof(u32), data);
}

void nvgpu_mem_wr_n(struct gk20a *g, struct nvgpu_mem *mem, u32 offset,
		void *src, u32 size)
{
	WARN_ON(offset & 3);
	WARN_ON(size & 3);

	if (mem->aperture == APERTURE_SYSMEM) {
		u8 *dest = (u8 *)mem->cpu_va + offset;

		WARN_ON(!mem->cpu_va);
#ifdef CONFIG_TEGRA_SIMULATION_PLATFORM
		if (size)
			nvgpu_log(g, gpu_dbg_mem, " %p = 0x%x ... [%d bytes]",
					dest, *src, size);
#endif
		memcpy(dest, src, size);
	} else if (mem->aperture == APERTURE_VIDMEM) {
		u32 *src_u32 = src;

		nvgpu_pramin_access_batched(g, mem, offset, size,
				pramin_access_batch_wr_n, &src_u32);
		if (!mem->skip_wmb)
			wmb();
	} else {
		WARN_ON("Accessing unallocated nvgpu_mem");
	}
}

static void pramin_access_batch_set(struct gk20a *g, u32 start, u32 words, u32 **arg)
{
	struct nvgpu_os_linux *l = nvgpu_os_linux_from_gk20a(g);
	u32 r = start, repeat = **arg;

	if (!l->regs) {
		__gk20a_warn_on_no_regs();
		return;
	}

	while (words--) {
		writel_relaxed(repeat, l->regs + r);
		r += sizeof(u32);
	}
}

void nvgpu_memset(struct gk20a *g, struct nvgpu_mem *mem, u32 offset,
		u32 c, u32 size)
{
	WARN_ON(offset & 3);
	WARN_ON(size & 3);
	WARN_ON(c & ~0xff);

	c &= 0xff;

	if (mem->aperture == APERTURE_SYSMEM) {
		u8 *dest = (u8 *)mem->cpu_va + offset;

		WARN_ON(!mem->cpu_va);
#ifdef CONFIG_TEGRA_SIMULATION_PLATFORM
		if (size)
			nvgpu_log(g, gpu_dbg_mem, " %p = 0x%x [times %d]",
				dest, c, size);
#endif
		memset(dest, c, size);
	} else if (mem->aperture == APERTURE_VIDMEM) {
		u32 repeat_value = c | (c << 8) | (c << 16) | (c << 24);
		u32 *p = &repeat_value;

		nvgpu_pramin_access_batched(g, mem, offset, size,
				pramin_access_batch_set, &p);
		if (!mem->skip_wmb)
			wmb();
	} else {
		WARN_ON("Accessing unallocated nvgpu_mem");
	}
}

/*
 * Obtain a SYSMEM address from a Linux SGL. This should eventually go away
 * and/or become private to this file once all bad usages of Linux SGLs are
 * cleaned up in the driver.
 */
u64 nvgpu_mem_get_addr_sgl(struct gk20a *g, struct scatterlist *sgl)
{
	if (nvgpu_is_enabled(g, NVGPU_MM_USE_PHYSICAL_SG) ||
	    !nvgpu_iommuable(g))
		return g->ops.mm.gpu_phys_addr(g, NULL,
			__nvgpu_sgl_phys(g, (struct nvgpu_sgl *)sgl));

	if (sg_dma_address(sgl) == 0)
		return g->ops.mm.gpu_phys_addr(g, NULL,
			__nvgpu_sgl_phys(g, (struct nvgpu_sgl *)sgl));

	if (sg_dma_address(sgl) == DMA_ERROR_CODE)
		return 0;

	return nvgpu_mem_iommu_translate(g, sg_dma_address(sgl));
}

/*
 * Obtain the address the GPU should use from the %mem assuming this is a SYSMEM
 * allocation.
 */
static u64 nvgpu_mem_get_addr_sysmem(struct gk20a *g, struct nvgpu_mem *mem)
{
	return nvgpu_mem_get_addr_sgl(g, mem->priv.sgt->sgl);
}

/*
 * Return the base address of %mem. Handles whether this is a VIDMEM or SYSMEM
 * allocation.
 *
 * Note: this API does not make sense to use for _VIDMEM_ buffers with greater
 * than one scatterlist chunk. If there's more than one scatterlist chunk then
 * the buffer will not be contiguous. As such the base address probably isn't
 * very useful. This is true for SYSMEM as well, if there's no IOMMU.
 *
 * However! It _is_ OK to use this on discontiguous sysmem buffers _if_ there's
 * an IOMMU present and enabled for the GPU.
 *
 * %attrs can be NULL. If it is not NULL then it may be inspected to determine
 * if the address needs to be modified before writing into a PTE.
 */
u64 nvgpu_mem_get_addr(struct gk20a *g, struct nvgpu_mem *mem)
{
	struct nvgpu_page_alloc *alloc;

	if (mem->aperture == APERTURE_SYSMEM)
		return nvgpu_mem_get_addr_sysmem(g, mem);

	/*
	 * Otherwise get the vidmem address.
	 */
	alloc = mem->vidmem_alloc;

	/* This API should not be used with > 1 chunks */
	WARN_ON(alloc->nr_chunks != 1);

	return alloc->base;
}

/*
 * This should only be used on contiguous buffers regardless of whether
 * there's an IOMMU present/enabled. This applies to both SYSMEM and
 * VIDMEM.
 */
u64 nvgpu_mem_get_phys_addr(struct gk20a *g, struct nvgpu_mem *mem)
{
	/*
	 * For a VIDMEM buf, this is identical to simply get_addr() so just fall
	 * back to that.
	 */
	if (mem->aperture == APERTURE_VIDMEM)
		return nvgpu_mem_get_addr(g, mem);

	return __nvgpu_sgl_phys(g, (struct nvgpu_sgl *)mem->priv.sgt->sgl);
}

/*
 * Be careful how you use this! You are responsible for correctly freeing this
 * memory.
 */
int nvgpu_mem_create_from_mem(struct gk20a *g,
			      struct nvgpu_mem *dest, struct nvgpu_mem *src,
			      int start_page, int nr_pages)
{
	int ret;
	u64 start = start_page * PAGE_SIZE;
	u64 size = nr_pages * PAGE_SIZE;
	dma_addr_t new_iova;

	if (src->aperture != APERTURE_SYSMEM)
		return -EINVAL;

	/* Some silly things a caller might do... */
	if (size > src->size)
		return -EINVAL;
	if ((start + size) > src->size)
		return -EINVAL;

	dest->mem_flags = src->mem_flags | NVGPU_MEM_FLAG_SHADOW_COPY;
	dest->aperture  = src->aperture;
	dest->skip_wmb  = src->skip_wmb;
	dest->size      = size;

	/*
	 * Re-use the CPU mapping only if the mapping was made by the DMA API.
	 *
	 * Bug 2040115: the DMA API wrapper makes the mapping that we should
	 * re-use.
	 */
	if (!(src->priv.flags & NVGPU_DMA_NO_KERNEL_MAPPING) ||
	    nvgpu_is_enabled(g, NVGPU_USE_COHERENT_SYSMEM))
		dest->cpu_va = src->cpu_va + (PAGE_SIZE * start_page);

	dest->priv.pages = src->priv.pages + start_page;
	dest->priv.flags = src->priv.flags;

	new_iova = sg_dma_address(src->priv.sgt->sgl) ?
		sg_dma_address(src->priv.sgt->sgl) + start : 0;

	/*
	 * Make a new SG table that is based only on the subset of pages that
	 * is passed to us. This table gets freed by the dma free routines.
	 */
	if (src->priv.flags & NVGPU_DMA_NO_KERNEL_MAPPING)
		ret = nvgpu_get_sgtable_from_pages(g, &dest->priv.sgt,
						   src->priv.pages + start_page,
						   new_iova, size);
	else
		ret = nvgpu_get_sgtable(g, &dest->priv.sgt, dest->cpu_va,
					new_iova, size);

	return ret;
}

int __nvgpu_mem_create_from_pages(struct gk20a *g, struct nvgpu_mem *dest,
				  struct page **pages, int nr_pages)
{
	struct sg_table *sgt;
	struct page **our_pages =
		nvgpu_kmalloc(g, sizeof(struct page *) * nr_pages);

	if (!our_pages)
		return -ENOMEM;

	memcpy(our_pages, pages, sizeof(struct page *) * nr_pages);

	if (nvgpu_get_sgtable_from_pages(g, &sgt, pages, 0,
					 nr_pages * PAGE_SIZE)) {
		nvgpu_kfree(g, our_pages);
		return -ENOMEM;
	}

	/*
	 * If we are making an SGT from physical pages we can be reasonably
	 * certain that this should bypass the SMMU - thus we set the DMA (aka
	 * IOVA) address to 0. This tells the GMMU mapping code to not make a
	 * mapping directed to the SMMU.
	 */
	sg_dma_address(sgt->sgl) = 0;

	dest->mem_flags  = __NVGPU_MEM_FLAG_NO_DMA;
	dest->aperture   = APERTURE_SYSMEM;
	dest->skip_wmb   = 0;
	dest->size       = PAGE_SIZE * nr_pages;

	dest->priv.flags = 0;
	dest->priv.pages = our_pages;
	dest->priv.sgt   = sgt;

	return 0;
}

#ifdef CONFIG_TEGRA_GK20A_NVHOST
int __nvgpu_mem_create_from_phys(struct gk20a *g, struct nvgpu_mem *dest,
				 u64 src_phys, int nr_pages)
{
	struct page **pages =
		nvgpu_kmalloc(g, sizeof(struct page *) * nr_pages);
	int i, ret = 0;

	if (!pages)
		return -ENOMEM;

	for (i = 0; i < nr_pages; i++)
		pages[i] = phys_to_page(src_phys + PAGE_SIZE * i);

	ret = __nvgpu_mem_create_from_pages(g, dest, pages, nr_pages);
	nvgpu_kfree(g, pages);

	return ret;
}
#endif

static struct nvgpu_sgl *nvgpu_mem_linux_sgl_next(struct nvgpu_sgl *sgl)
{
	return (struct nvgpu_sgl *)sg_next((struct scatterlist *)sgl);
}

static u64 nvgpu_mem_linux_sgl_phys(struct gk20a *g, struct nvgpu_sgl *sgl)
{
	return (u64)__nvgpu_sgl_phys(g, sgl);
}

static u64 nvgpu_mem_linux_sgl_dma(struct nvgpu_sgl *sgl)
{
	return (u64)sg_dma_address((struct scatterlist *)sgl);
}

static u64 nvgpu_mem_linux_sgl_length(struct nvgpu_sgl *sgl)
{
	return (u64)((struct scatterlist *)sgl)->length;
}

static u64 nvgpu_mem_linux_sgl_gpu_addr(struct gk20a *g,
					struct nvgpu_sgl *sgl,
					struct nvgpu_gmmu_attrs *attrs)
{
	if (sg_dma_address((struct scatterlist *)sgl) == 0)
		return g->ops.mm.gpu_phys_addr(g, attrs,
				__nvgpu_sgl_phys(g, sgl));

	if (sg_dma_address((struct scatterlist *)sgl) == DMA_ERROR_CODE)
		return 0;

	return nvgpu_mem_iommu_translate(g,
				sg_dma_address((struct scatterlist *)sgl));
}

static bool nvgpu_mem_linux_sgt_iommuable(struct gk20a *g,
					  struct nvgpu_sgt *sgt)
{
	if (nvgpu_is_enabled(g, NVGPU_MM_USE_PHYSICAL_SG))
		return false;
	return true;
}

static void nvgpu_mem_linux_sgl_free(struct gk20a *g, struct nvgpu_sgt *sgt)
{
	/*
	 * Free this SGT. All we do is free the passed SGT. The actual Linux
	 * SGT/SGL needs to be freed separately.
	 */
	nvgpu_kfree(g, sgt);
}

static const struct nvgpu_sgt_ops nvgpu_linux_sgt_ops = {
	.sgl_next      = nvgpu_mem_linux_sgl_next,
	.sgl_phys      = nvgpu_mem_linux_sgl_phys,
	.sgl_dma       = nvgpu_mem_linux_sgl_dma,
	.sgl_length    = nvgpu_mem_linux_sgl_length,
	.sgl_gpu_addr  = nvgpu_mem_linux_sgl_gpu_addr,
	.sgt_iommuable = nvgpu_mem_linux_sgt_iommuable,
	.sgt_free      = nvgpu_mem_linux_sgl_free,
};

static struct nvgpu_sgt *__nvgpu_mem_get_sgl_from_vidmem(
	struct gk20a *g,
	struct scatterlist *linux_sgl)
{
	struct nvgpu_page_alloc *vidmem_alloc;

	vidmem_alloc = nvgpu_vidmem_get_page_alloc(linux_sgl);
	if (!vidmem_alloc)
		return NULL;

	return &vidmem_alloc->sgt;
}

struct nvgpu_sgt *nvgpu_linux_sgt_create(struct gk20a *g, struct sg_table *sgt)
{
	struct nvgpu_sgt *nvgpu_sgt;
	struct scatterlist *linux_sgl = sgt->sgl;

	if (nvgpu_addr_is_vidmem_page_alloc(sg_dma_address(linux_sgl)))
		return __nvgpu_mem_get_sgl_from_vidmem(g, linux_sgl);

	nvgpu_sgt = nvgpu_kzalloc(g, sizeof(*nvgpu_sgt));
	if (!nvgpu_sgt)
		return NULL;

	nvgpu_log(g, gpu_dbg_sgl, "Making Linux SGL!");

	nvgpu_sgt->sgl = (struct nvgpu_sgl *)linux_sgl;
	nvgpu_sgt->ops = &nvgpu_linux_sgt_ops;

	return nvgpu_sgt;
}

struct nvgpu_sgt *nvgpu_sgt_create_from_mem(struct gk20a *g,
					    struct nvgpu_mem *mem)
{
	return nvgpu_linux_sgt_create(g, mem->priv.sgt);
}
