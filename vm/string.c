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
#include "native.h"
#include "string.h"

void string_repr(void *ptr)
{
	string_t *string = ptr;
	printf("%s", string->str);
}

void string_visit(visitor_t *vs, void *data)
{
	string_t *str = data;
	if (str->copy)
		str->str = data+sizeof(string_t);
}

void* _string(heap_t *heap, char *str, int copy)
{
	int hsize = sizeof(string_t);
	int ssize = strlen(str)+1;
	if (copy)
		hsize += ssize;

	void *mem = heap_alloc(heap, hsize, t_string);
	string_t *string = mem;
	string->size = ssize;
	if (copy) {
		string->str = mem + sizeof(string_t);
		memcpy(string->str, str, ssize);
		string->copy = 1;
	} else {
		string->copy = 0;
		string->str = str;
	}

	return make_ptr(string, id_ptr);
}

static int symbol_to_string(vm_thread_t *thread, obj_t *sym)
{
	SAFE_ASSERT(sym->tag == id_symbol);
	char *str = PTR(*sym);

	RESULT_PTR(_string(&thread->heap, str, 0));
}
MAKE_NATIVE_UNARY(symbol_to_string);

static int string_ref(vm_thread_t *thread, obj_t *ostr, obj_t *opos)
{
	SAFE_ASSERT(IS_TYPE(*ostr, t_string));
	SAFE_ASSERT(opos->tag == id_fixnum);
	string_t *str = get_typed(*ostr, t_string);
	int pos = FIXNUM(*opos);
	SAFE_ASSERT(pos < str->size-1);

	RESULT_CHAR(str->str[pos]);
}
MAKE_NATIVE_BINARY(string_ref);

static int string_length(vm_thread_t *thread, obj_t *ostr)
{
	SAFE_ASSERT(IS_TYPE(*ostr, t_string));
	string_t *str = get_typed(*ostr, t_string);

	RESULT_FIXNUM(str->size-1);
}
MAKE_NATIVE_UNARY(string_length);

static int is_string(vm_thread_t *thread, obj_t *obj)
{
	RESULT_BOOL(IS_TYPE(*obj, t_string));
}
MAKE_NATIVE_UNARY(is_string);

static int string_eq(vm_thread_t *thread, obj_t *a, obj_t *b)
{
	SAFE_ASSERT(IS_TYPE(*a, t_string));
	SAFE_ASSERT(IS_TYPE(*b, t_string));
	string_t *sa = get_typed(*a, t_string);
	string_t *sb = get_typed(*b, t_string);

	RESULT_BOOL(strcmp(sa->str, sb->str) == 0);
}
MAKE_NATIVE_BINARY(string_eq);

void ns_install_string(hash_table_t *tbl)
{
	ns_install_native(tbl, "symbol->string", &symbol_to_string_nt);
	ns_install_native(tbl, "string-ref", &string_ref_nt);
	ns_install_native(tbl, "string-length", &string_length_nt);
	ns_install_native(tbl, "string?", &is_string_nt);
	ns_install_native(tbl, "string=?", &string_eq_nt);
}
