/*
 * Nvgpu Semaphores
 *
 * Copyright (c) 2014-2018, NVIDIA CORPORATION.  All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <nvgpu/dma.h>
#include <nvgpu/gmmu.h>
#include <nvgpu/semaphore.h>
#include <nvgpu/kmem.h>
#include <nvgpu/bug.h>
#include <nvgpu/sizes.h>

#include "gk20a/gk20a.h"
#include "gk20a/mm_gk20a.h"

#define pool_to_gk20a(p) ((p)->sema_sea->gk20a)

#define __lock_sema_sea(s)						\
	do {								\
		gpu_sema_verbose_dbg(s->gk20a, "Acquiring sema lock..."); \
		nvgpu_mutex_acquire(&s->sea_lock);			\
		gpu_sema_verbose_dbg(s->gk20a, "Sema lock aquried!");	\
	} while (0)

#define __unlock_sema_sea(s)						\
	do {								\
		nvgpu_mutex_release(&s->sea_lock);			\
		gpu_sema_verbose_dbg(s->gk20a, "Released sema lock");	\
	} while (0)

/*
 * Return the sema_sea pointer.
 */
struct nvgpu_semaphore_sea *nvgpu_semaphore_get_sea(struct gk20a *g)
{
	return g->sema_sea;
}

static int __nvgpu_semaphore_sea_grow(struct nvgpu_semaphore_sea *sea)
{
	int ret = 0;
	struct gk20a *gk20a = sea->gk20a;
	u32 i;

	__lock_sema_sea(sea);

	ret = nvgpu_dma_alloc_sys(gk20a,
				  PAGE_SIZE * SEMAPHORE_POOL_COUNT,
				  &sea->sea_mem);
	if (ret)
		goto out;

	sea->size = SEMAPHORE_POOL_COUNT;
	sea->map_size = SEMAPHORE_POOL_COUNT * PAGE_SIZE;

	/*
	 * Start the semaphores at values that will soon overflow the 32-bit
	 * integer range. This way any buggy comparisons would start to fail
	 * sooner rather than later.
	 */
	for (i = 0; i < PAGE_SIZE * SEMAPHORE_POOL_COUNT; i += 4)
		nvgpu_mem_wr(gk20a, &sea->sea_mem, i, 0xfffffff0);

out:
	__unlock_sema_sea(sea);
	return ret;
}

void nvgpu_semaphore_sea_destroy(struct gk20a *g)
{
	if (!g->sema_sea)
		return;

	nvgpu_dma_free(g, &g->sema_sea->sea_mem);
	nvgpu_mutex_destroy(&g->sema_sea->sea_lock);
	nvgpu_kfree(g, g->sema_sea);
	g->sema_sea = NULL;
}

/*
 * Create the semaphore sea. Only create it once - subsequent calls to this will
 * return the originally created sea pointer.
 */
struct nvgpu_semaphore_sea *nvgpu_semaphore_sea_create(struct gk20a *g)
{
	if (g->sema_sea)
		return g->sema_sea;

	g->sema_sea = nvgpu_kzalloc(g, sizeof(*g->sema_sea));
	if (!g->sema_sea)
		return NULL;

	g->sema_sea->size = 0;
	g->sema_sea->page_count = 0;
	g->sema_sea->gk20a = g;
	nvgpu_init_list_node(&g->sema_sea->pool_list);
	if (nvgpu_mutex_init(&g->sema_sea->sea_lock))
		goto cleanup_free;

	if (__nvgpu_semaphore_sea_grow(g->sema_sea))
		goto cleanup_destroy;

	gpu_sema_dbg(g, "Created semaphore sea!");
	return g->sema_sea;

cleanup_destroy:
	nvgpu_mutex_destroy(&g->sema_sea->sea_lock);
cleanup_free:
	nvgpu_kfree(g, g->sema_sea);
	g->sema_sea = NULL;
	gpu_sema_dbg(g, "Failed to creat semaphore sea!");
	return NULL;
}

static int __semaphore_bitmap_alloc(unsigned long *bitmap, unsigned long len)
{
	unsigned long idx = find_first_zero_bit(bitmap, len);

	if (idx == len)
		return -ENOSPC;

	set_bit(idx, bitmap);

	return (int)idx;
}

/*
 * Allocate a pool from the sea.
 */
int nvgpu_semaphore_pool_alloc(struct nvgpu_semaphore_sea *sea,
			       struct nvgpu_semaphore_pool **pool)
{
	struct nvgpu_semaphore_pool *p;
	unsigned long page_idx;
	int ret;

	p = nvgpu_kzalloc(sea->gk20a, sizeof(*p));
	if (!p)
		return -ENOMEM;

	__lock_sema_sea(sea);

	ret = nvgpu_mutex_init(&p->pool_lock);
	if (ret)
		goto fail;

	ret = __semaphore_bitmap_alloc(sea->pools_alloced,
				       SEMAPHORE_POOL_COUNT);
	if (ret < 0)
		goto fail_alloc;

	page_idx = (unsigned long)ret;

	p->page_idx = page_idx;
	p->sema_sea = sea;
	nvgpu_init_list_node(&p->pool_list_entry);
	nvgpu_ref_init(&p->ref);

	sea->page_count++;
	nvgpu_list_add(&p->pool_list_entry, &sea->pool_list);
	__unlock_sema_sea(sea);

	gpu_sema_dbg(sea->gk20a,
		     "Allocated semaphore pool: page-idx=%d", p->page_idx);

	*pool = p;
	return 0;

fail_alloc:
	nvgpu_mutex_destroy(&p->pool_lock);
fail:
	__unlock_sema_sea(sea);
	nvgpu_kfree(sea->gk20a, p);
	gpu_sema_dbg(sea->gk20a, "Failed to allocate semaphore pool!");
	return ret;
}

/*
 * Map a pool into the passed vm's address space. This handles both the fixed
 * global RO mapping and the non-fixed private RW mapping.
 */
int nvgpu_semaphore_pool_map(struct nvgpu_semaphore_pool *p,
			     struct vm_gk20a *vm)
{
	int err = 0;
	u64 addr;

	if (p->mapped)
		return -EBUSY;

	gpu_sema_dbg(pool_to_gk20a(p),
		     "Mapping semaphore pool! (idx=%d)", p->page_idx);

	/*
	 * Take the sea lock so that we don't race with a possible change to the
	 * nvgpu_mem in the sema sea.
	 */
	__lock_sema_sea(p->sema_sea);

	addr = nvgpu_gmmu_map_fixed(vm, &p->sema_sea->sea_mem,
				    p->sema_sea->gpu_va,
				    p->sema_sea->map_size,
				    0, gk20a_mem_flag_read_only, 0,
				    p->sema_sea->sea_mem.aperture);
	if (!addr) {
		err = -ENOMEM;
		goto fail_unlock;
	}

	p->gpu_va_ro = addr;
	p->mapped = 1;

	gpu_sema_dbg(pool_to_gk20a(p),
		     "  %d: GPU read-only  VA = 0x%llx",
		     p->page_idx, p->gpu_va_ro);

	/*
	 * Now the RW mapping. This is a bit more complicated. We make a
	 * nvgpu_mem describing a page of the bigger RO space and then map
	 * that. Unlike above this does not need to be a fixed address.
	 */
	err = nvgpu_mem_create_from_mem(vm->mm->g,
					&p->rw_mem, &p->sema_sea->sea_mem,
					p->page_idx, 1);
	if (err)
		goto fail_unmap;

	addr = nvgpu_gmmu_map(vm, &p->rw_mem, SZ_4K, 0,
			      gk20a_mem_flag_none, 0,
			      p->rw_mem.aperture);

	if (!addr) {
		err = -ENOMEM;
		goto fail_free_submem;
	}

	p->gpu_va = addr;

	__unlock_sema_sea(p->sema_sea);

	gpu_sema_dbg(pool_to_gk20a(p),
		     "  %d: GPU read-write VA = 0x%llx",
		     p->page_idx, p->gpu_va);
	gpu_sema_dbg(pool_to_gk20a(p),
		     "  %d: CPU VA            = 0x%p",
		     p->page_idx, p->rw_mem.cpu_va);

	return 0;

fail_free_submem:
	nvgpu_dma_free(pool_to_gk20a(p), &p->rw_mem);
fail_unmap:
	nvgpu_gmmu_unmap(vm, &p->sema_sea->sea_mem, p->gpu_va_ro);
	gpu_sema_dbg(pool_to_gk20a(p),
		     "  %d: Failed to map semaphore pool!", p->page_idx);
fail_unlock:
	__unlock_sema_sea(p->sema_sea);
	return err;
}

/*
 * Unmap a semaphore_pool.
 */
void nvgpu_semaphore_pool_unmap(struct nvgpu_semaphore_pool *p,
				struct vm_gk20a *vm)
{
	__lock_sema_sea(p->sema_sea);

	nvgpu_gmmu_unmap(vm, &p->sema_sea->sea_mem, p->gpu_va_ro);
	nvgpu_gmmu_unmap(vm, &p->rw_mem, p->gpu_va);
	nvgpu_dma_free(pool_to_gk20a(p), &p->rw_mem);

	p->gpu_va = 0;
	p->gpu_va_ro = 0;
	p->mapped = 0;

	__unlock_sema_sea(p->sema_sea);

	gpu_sema_dbg(pool_to_gk20a(p),
		     "Unmapped semaphore pool! (idx=%d)", p->page_idx);
}

/*
 * Completely free a semaphore_pool. You should make sure this pool is not
 * mapped otherwise there's going to be a memory leak.
 */
static void nvgpu_semaphore_pool_free(struct nvgpu_ref *ref)
{
	struct nvgpu_semaphore_pool *p =
		container_of(ref, struct nvgpu_semaphore_pool, ref);
	struct nvgpu_semaphore_sea *s = p->sema_sea;

	/* Freeing a mapped pool is a bad idea. */
	WARN_ON(p->mapped || p->gpu_va || p->gpu_va_ro);

	__lock_sema_sea(s);
	nvgpu_list_del(&p->pool_list_entry);
	clear_bit(p->page_idx, s->pools_alloced);
	s->page_count--;
	__unlock_sema_sea(s);

	nvgpu_mutex_destroy(&p->pool_lock);

	gpu_sema_dbg(pool_to_gk20a(p),
		     "Freed semaphore pool! (idx=%d)", p->page_idx);
	nvgpu_kfree(p->sema_sea->gk20a, p);
}

void nvgpu_semaphore_pool_get(struct nvgpu_semaphore_pool *p)
{
	nvgpu_ref_get(&p->ref);
}

void nvgpu_semaphore_pool_put(struct nvgpu_semaphore_pool *p)
{
	nvgpu_ref_put(&p->ref, nvgpu_semaphore_pool_free);
}

/*
 * Get the address for a semaphore_pool - if global is true then return the
 * global RO address instead of the RW address owned by the semaphore's VM.
 */
u64 __nvgpu_semaphore_pool_gpu_va(struct nvgpu_semaphore_pool *p, bool global)
{
	if (!global)
		return p->gpu_va;

	return p->gpu_va_ro + (PAGE_SIZE * p->page_idx);
}

static int __nvgpu_init_hw_sema(struct channel_gk20a *ch)
{
	int hw_sema_idx;
	int ret = 0;
	struct nvgpu_semaphore_int *hw_sema;
	struct nvgpu_semaphore_pool *p = ch->vm->sema_pool;
	int current_value;

	BUG_ON(!p);

	nvgpu_mutex_acquire(&p->pool_lock);

	/* Find an available HW semaphore. */
	hw_sema_idx = __semaphore_bitmap_alloc(p->semas_alloced,
					       PAGE_SIZE / SEMAPHORE_SIZE);
	if (hw_sema_idx < 0) {
		ret = hw_sema_idx;
		goto fail;
	}

	hw_sema = nvgpu_kzalloc(ch->g, sizeof(struct nvgpu_semaphore_int));
	if (!hw_sema) {
		ret = -ENOMEM;
		goto fail_free_idx;
	}

	ch->hw_sema = hw_sema;
	hw_sema->ch = ch;
	hw_sema->location.pool = p;
	hw_sema->location.offset = SEMAPHORE_SIZE * hw_sema_idx;
	current_value = nvgpu_mem_rd(ch->g, &p->rw_mem,
			hw_sema->location.offset);
	nvgpu_atomic_set(&hw_sema->next_value, current_value);

	nvgpu_mutex_release(&p->pool_lock);

	return 0;

fail_free_idx:
	clear_bit(hw_sema_idx, p->semas_alloced);
fail:
	nvgpu_mutex_release(&p->pool_lock);
	return ret;
}

/*
 * Free the channel used semaphore index
 */
void nvgpu_semaphore_free_hw_sema(struct channel_gk20a *ch)
{
	struct nvgpu_semaphore_pool *p = ch->vm->sema_pool;
	struct nvgpu_semaphore_int *hw_sema = ch->hw_sema;
	int idx = hw_sema->location.offset / SEMAPHORE_SIZE;

	BUG_ON(!p);

	nvgpu_mutex_acquire(&p->pool_lock);

	clear_bit(idx, p->semas_alloced);

	nvgpu_kfree(ch->g, hw_sema);
	ch->hw_sema = NULL;

	nvgpu_mutex_release(&p->pool_lock);
}

/*
 * Allocate a semaphore from the passed pool.
 *
 * Since semaphores are ref-counted there's no explicit free for external code
 * to use. When the ref-count hits 0 the internal free will happen.
 */
struct nvgpu_semaphore *nvgpu_semaphore_alloc(struct channel_gk20a *ch)
{
	struct nvgpu_semaphore *s;
	int ret;

	if (!ch->hw_sema) {
		ret = __nvgpu_init_hw_sema(ch);
		if (ret)
			return NULL;
	}

	s = nvgpu_kzalloc(ch->g, sizeof(*s));
	if (!s)
		return NULL;

	nvgpu_ref_init(&s->ref);
	s->g = ch->g;
	s->location = ch->hw_sema->location;
	nvgpu_atomic_set(&s->value, 0);

	/*
	 * Take a ref on the pool so that we can keep this pool alive for
	 * as long as this semaphore is alive.
	 */
	nvgpu_semaphore_pool_get(s->location.pool);

	gpu_sema_dbg(ch->g, "Allocated semaphore (c=%d)", ch->chid);

	return s;
}

static void nvgpu_semaphore_free(struct nvgpu_ref *ref)
{
	struct nvgpu_semaphore *s =
		container_of(ref, struct nvgpu_semaphore, ref);

	nvgpu_semaphore_pool_put(s->location.pool);

	nvgpu_kfree(s->g, s);
}

void nvgpu_semaphore_put(struct nvgpu_semaphore *s)
{
	nvgpu_ref_put(&s->ref, nvgpu_semaphore_free);
}

void nvgpu_semaphore_get(struct nvgpu_semaphore *s)
{
	nvgpu_ref_get(&s->ref);
}
