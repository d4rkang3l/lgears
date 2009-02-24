/*
 * Copyright (C) 2009 - Stepan Zastupov
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */
#include <unistd.h>
#include <errno.h>
#include "memory.h"
#include "heap.h"

#define balign 7
#define align_up(s)	(((s)+balign) & ~balign)

#define BHDR_SIZE sizeof(block_hdr_t)

static void copy_heap_reset(copy_heap_t *heap)
{
	int pad = align_up(BHDR_SIZE)-BHDR_SIZE;
	heap->pos = heap->mem + pad;
	heap->free_mem = heap->size - pad;
	heap->blocks = 0;
}

static void copy_heap_init(copy_heap_t *heap, void *mem, int size)
{
	heap->size = size;
	heap->mem = mem;

	copy_heap_reset(heap);
}

/*
 * All pointers should be aligned by wordsize
 * Assume that pos is always aligned address - BHDR_SIZE
 */
static void* copy_heap_alloc(copy_heap_t *heap, size_t size)
{
	size_t minimal = size+BHDR_SIZE;
	if (minimal > heap->free_mem) {
		printf("out of free mem on heap (need %ld)\n", minimal);
		return NULL;
	}

	size_t required = align_up(minimal)-BHDR_SIZE;

	block_hdr_t *hdr = heap->pos;
	hdr->forward = NULL;
	heap->pos += BHDR_SIZE;
	heap->free_mem -= BHDR_SIZE;
	/*
	 * Align size to required if we have enaught memory
	 */
	if (required <= heap->free_mem) {
		hdr->size = required;
		heap->free_mem -= required;
	} else {
		hdr->size = size;
		heap->free_mem = 0;
	}
	void *res = heap->pos;

	heap->pos += hdr->size;
	heap->blocks++;

	printf("allocated %d bytes\n", hdr->size);

	return res;
}

static void* copy_heap_copy(copy_heap_t *heap, void *p, size_t size)
{
	if (size > heap->free_mem)
		FATAL("Totaly fucking out of memory");
	void *res = heap->pos;
	memcpy(res, p, size);
	heap->pos += size;
	heap->free_mem -= size;
	heap->blocks++;
	return res;
}

static void heap_swap(heap_t *heap)
{
	copy_heap_reset(heap->from);
	copy_heap_t *tmp = heap->from;
	heap->from = heap->to;
	heap->to = tmp;
}

void* heap_alloc(heap_t *heap, int size)
{
	void *res = copy_heap_alloc(heap->from, size);
	if (!res) {
		printf("!!!Starting garbage collection, DON'T PANIC!!!!\n");
		heap->vm_inspect(&heap->visitor, heap->vm);
		heap_swap(heap);
		res = copy_heap_alloc(heap->from, size);
		if (!res)
			FATAL("Totaly fucking out of memory");
	}
	return res;
}

void* heap_alloc0(heap_t *heap, int size)
{
	void *ptr = heap_alloc(heap, size);
	memset(ptr, 0, size);
	return ptr;
}

static void heap_mark(visitor_t *visitor, obj_t *obj)
{
	heap_t *heap = visitor->user_data;

	if (!obj->ptr || obj->tag != id_ptr)
		return;

	ptr_t ptr = { .ptr = obj->ptr };

	void *p = PTR_GET(ptr);
	p -= BHDR_SIZE;
	block_hdr_t *hdr = p;

	/*
	 * Use forward pointer if object already moved
	 */
	if (hdr->forward) {
		printf("Forwarding to %p\n", hdr->forward);
		PTR_SET(ptr, hdr->forward);
		obj->ptr = ptr.ptr;
		return;
	}

	/*
	 * Copy object to the second heap and update pointer
	 */
	void *new_pos = copy_heap_copy(heap->to, p, hdr->size+BHDR_SIZE);
	hdr->forward = new_pos + BHDR_SIZE; // Forward pointer from old memory to new
	hdr = new_pos;
	hdr->forward = NULL;
	new_pos += BHDR_SIZE;
	PTR_SET(ptr, new_pos);
	obj->ptr = ptr.ptr;

	/*
	 * If type provide visit function - call it
	 */
	hobj_hdr_t *ohdr = new_pos;
	if (ohdr->type->visit)
		ohdr->type->visit(visitor, new_pos);
}

void heap_init(heap_t *heap, visitor_fun vm_inspect, void *vm)
{
	heap->from = &heap->heaps[0];
	heap->to = &heap->heaps[1];

	static int sc_page_size = 0;
	if (!sc_page_size)
		sc_page_size = sysconf(_SC_PAGE_SIZE);

	heap->page_size = sc_page_size*2;
	heap->page = mmap(NULL, heap->page_size,
			PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, 0, 0);
	if (heap->page == MAP_FAILED)
		FATAL("failed to mmap page: %s\n", strerror(errno));

	copy_heap_init(heap->from, heap->page, sc_page_size);
	copy_heap_init(heap->to, heap->page+sc_page_size, sc_page_size);

	heap->visitor.visit = heap_mark;
	heap->visitor.user_data = heap;
	heap->vm_inspect = vm_inspect;
	heap->vm = vm;
}

void heap_destroy(heap_t *heap)
{
	munmap(heap->page, heap->page_size);
}

void heap_stat(heap_t *heap)
{
	printf("mem used %d\n", heap->from->size - heap->from->free_mem);
}
