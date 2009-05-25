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
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <limits.h>
#include <dirent.h>

#include "native.h"
#include "struct.h"
#include "strings.h"

/*
 * This module pretend to be a typesafe interface to posix filesystem
 * operations. Only basic amount of operations is supported but you
 * always may use ffi at you own risk :)
 */

/* Remember? we are safe, so we have to make some types */
int t_dir;

typedef struct {
	DIR *dir;
	obj_t opath;
} dir_t;

static void dir_repr(void *ptr)
{
	dir_t *dir = ptr;
	string_t *path = PTR(dir->opath);
	printf("<dir: %s>", path->str);
}

static void dir_visit(visitor_t *vs, void *data)
{
	dir_t *dir = data;
	vs->visit(vs, &dir->opath);
}

/*
 * Stat call, scheme code should provide syntactic sugar
 * TODO: export inode type helpers
 */
static int fs_stat(vm_thread_t *thread, obj_t *opath)
{
	SAFE_ASSERT(IS_STRING(*opath));

	string_t *path = PTR(*opath);
	struct stat st = {0};

	if (stat(path->str, &st) == 0) {
		obj_t type_name = make_symbol("stat");
		struct_t *pstat = struct_new(&thread->heap.allocator,
									 &type_name,
									 10);
		fixnum_t fx;
		fx.tag = id_fixnum;
#define ST_SET(idx,v)							\
		fx.val = v;								\
		pstat->fields[idx] = fx.obj;

		ST_SET(0, st.st_dev);
		ST_SET(1, st.st_ino);
		ST_SET(2, st.st_mode);
		ST_SET(3, st.st_nlink);
		ST_SET(4, st.st_uid);
		ST_SET(5, st.st_gid);
		ST_SET(6, st.st_size);
		ST_SET(7, st.st_atime);
		ST_SET(8, st.st_mtime);
		ST_SET(9, st.st_ctime);

		RETURN_OBJ(make_ptr(pstat, id_ptr));
	} else {
		RETURN_OBJ(cfalse.obj);
	}
}
MAKE_NATIVE_UNARY(fs_stat);

static int fs_remove(vm_thread_t *thread, obj_t *opath)
{
	SAFE_ASSERT(IS_STRING(*opath));

	string_t *path = PTR(*opath);
	RETURN_BOOL(remove(path->str) == 0);
}
MAKE_NATIVE_UNARY(fs_remove);

static int fs_getcwd(vm_thread_t *thread)
{
	char path[PATH_MAX];
	if (getcwd(path, sizeof(path))) {
		RETURN_OBJ(_string(&thread->heap.allocator,
						   path,
						   1));
	} else {
		RETURN_OBJ(cfalse.obj);
	}
}
MAKE_NATIVE_NULLARY(fs_getcwd);

static int fs_opendir(vm_thread_t *thread, obj_t *opath)
{
	SAFE_ASSERT(IS_STRING(*opath));

	string_t *path = PTR(*opath);
	DIR *dir = opendir(path->str);
	if (dir) {
		dir_t *dt = heap_alloc(&thread->heap, sizeof(dir_t), t_dir);
		dt->opath = *opath;
		dt->dir = dir;
		RETURN_OBJ(make_ptr(dt, id_ptr));
	} else {
		RETURN_OBJ(cfalse.obj);
	}
}
MAKE_NATIVE_UNARY(fs_opendir);

static int fs_closedir(vm_thread_t *thread, obj_t *odir)
{
	SAFE_ASSERT(IS_TYPE(*odir, t_dir));
	dir_t *dt = PTR(*odir);

	RETURN_BOOL(closedir(dt->dir) == 0);
}
MAKE_NATIVE_UNARY(fs_closedir);

static int fs_readdir(vm_thread_t *thread, obj_t *odir)
{
	SAFE_ASSERT(IS_TYPE(*odir, t_dir));
	dir_t *dt = PTR(*odir);
	struct dirent *d_buf, *d_res;
	d_buf = alloca(offsetof(struct dirent, d_name)+PATH_MAX);
	if (readdir_r(dt->dir, d_buf, &d_res) == 0) {
		if (d_res) {
			RETURN_OBJ(_string(&thread->heap.allocator,
							   d_res->d_name, 1));
		} else {
			RETURN_OBJ(ceof.obj);
		}
	} else {
		RETURN_OBJ(cfalse.obj);
	}
}
MAKE_NATIVE_UNARY(fs_readdir);

void fs_init()
{
	t_dir = register_type("directory", dir_repr, dir_visit);

	ns_install_global("fs-stat", &fs_stat_nt);
	ns_install_global("fs-remove", &fs_remove_nt);
	ns_install_global("fs-getcwd", &fs_getcwd_nt);
	ns_install_global("fs-opendir", &fs_opendir_nt);
	ns_install_global("fs-closedir", &fs_closedir_nt);
	ns_install_global("fs-readdir", &fs_readdir_nt);
}