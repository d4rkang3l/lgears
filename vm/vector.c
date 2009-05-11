/*
 * This file is part of lGears scheme system
 * Copyright (C) 2009 Stepan Zastupov <redchrom@gmail.com>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * Public Licens along with this program, if not; see
 * <http://www.gnu.org/licenses>.
 */
#include "native.h"
#include "vector.h"
#include "primitives.h"

void vector_repr(void *ptr)
{
	vector_t *vec = ptr;
	printf("#(");
	int i;
	for (i = 0; i < vec->size; i++) {
		print_obj(vec->objects[i]);
		if (i < vec->size-1)
			printf(" ");
	}
	printf(")");
}

void vector_visit(visitor_t *vs, void *data)
{
	vector_t *vec = data;
	vec->objects = data+sizeof(vector_t);
	int i;
	for (i = 0; i < vec->size; i++)
		vs->visit(vs, &vec->objects[i]);
}

vector_t* vector_new(allocator_t *al, int size)
{
	void *mem = allocator_alloc(al, sizeof(vector_t)+sizeof(obj_t)*size, t_vector);
	vector_t *vec = mem;
	vec->objects = mem+sizeof(vector_t);
	vec->size = size;

	return vec;
}

static int vector(vm_thread_t *thread, obj_t *argv, int argc)
{
	int count = argc-1;
	vector_t *vec = vector_new(&thread->heap.allocator, count);

	int i;
	for (i = 0; i < count; i++)
		vec->objects[i] = argv[i+1];

	RESULT_PTR(make_ptr(vec, id_ptr));
}
MAKE_NATIVE_VARIADIC(vector, 0);

static int make_vector(vm_thread_t *thread, obj_t *count, obj_t *fill)
{
	SAFE_ASSERT(IS_FIXNUM(*count));

	vector_t *vec = vector_new(&thread->heap.allocator, FIXNUM(*count));
	int i;
	for (i = 0; i < vec->size; i++)
		vec->objects[i] = *fill;

	RESULT_PTR(make_ptr(vec, id_ptr));
}
MAKE_NATIVE_BINARY(make_vector);

static int vector_length(vm_thread_t *thread, obj_t *obj)
{
	SAFE_ASSERT(IS_VECTOR(*obj));
	vector_t *vec = PTR(*obj);

	RESULT_FIXNUM(vec->size);
}
MAKE_NATIVE_UNARY(vector_length);

static int is_vector(vm_thread_t *thread, obj_t *obj)
{
	RESULT_BOOL(IS_VECTOR(*obj));
}
MAKE_NATIVE_UNARY(is_vector);

static int vector_set(vm_thread_t *thread, obj_t *obj, obj_t *opos, obj_t *val)
{
	SAFE_ASSERT(IS_VECTOR(*obj));
	SAFE_ASSERT(obj->tag != id_const_ptr);
	vector_t *vec = PTR(*obj);
	int pos = FIXNUM(*opos);
	SAFE_ASSERT(vec->size > pos);

	vec->objects[pos] = *val;
	MARK_MODIFIED(&thread->heap, vec);

	RESULT_OBJ(cvoid.obj);
}
MAKE_NATIVE_TERNARY(vector_set);

static int vector_ref(vm_thread_t *thread, obj_t *obj, obj_t *opos)
{
	SAFE_ASSERT(IS_VECTOR(*obj));
	SAFE_ASSERT(IS_FIXNUM(*opos));
	vector_t *vec = PTR(*obj);
	int pos = FIXNUM(*opos);
	SAFE_ASSERT(vec->size > pos);

	RESULT_OBJ(vec->objects[pos]);
}
MAKE_NATIVE_BINARY(vector_ref);

static int vector_to_list(vm_thread_t *thread, obj_t *obj)
{
	SAFE_ASSERT(IS_VECTOR(*obj));
	vector_t *vec = PTR(*obj);
	void *res = _list(&thread->heap, vec->objects, vec->size);
	RESULT_PTR(res);
}
MAKE_NATIVE_UNARY(vector_to_list);

void ns_install_vector(hash_table_t *tbl)
{
	ns_install_native(tbl, "vector", &vector_nt);
	ns_install_native(tbl, "vector?", &is_vector_nt);
	ns_install_native(tbl, "vector-length", &vector_length_nt);
	ns_install_native(tbl, "vector-set!", &vector_set_nt);
	ns_install_native(tbl, "vector-ref", &vector_ref_nt);
	ns_install_native(tbl, "vector->list", &vector_to_list_nt);
	ns_install_native(tbl, "$make-vector", &make_vector_nt);
}
