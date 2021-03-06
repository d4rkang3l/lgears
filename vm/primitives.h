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
#ifndef PRIMITIVES_H
#define PRIMITIVES_H
#include "native.h"
#include "struct.h"
#include "strings.h"
#include "bytevector.h"

extern int t_pair;

extern const native_func_t vm_exit_nt;

void exception_handler_init(vm_thread_t *thread);
void primitives_init();
void primitives_cleanup();

typedef struct {
	obj_t car, cdr;
	/*
	 * FIXME store next value only for list (allocate additional
	 * memory in _cons)
	 */
	unsigned list:1;
	unsigned length:31;
} pair_t;

obj_t _list(vm_thread_t *thread, obj_t *argv, int argc);
obj_t _cons(allocator_t *al, obj_t *car, obj_t *cdr);

#define IS_PAIR(obj) IS_TYPE(obj, t_pair)
#define IS_LIST(o) ((IS_PAIR(o) && ((pair_t*)PTR(o))->list) || IS_NULL(o))

typedef struct {
	obj_t func;
} continuation_t;

#endif /* PRIMITIVES_H */
