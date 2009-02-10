CFLAGS += -Wall -ggdb -O2

vm_obj = vm.o heap.o primitives.o hash.o
targets = vm

include include.mk

# FIXME
# Add mzscheme variant
r6rs = ypsilon --sitelib=./scheme

regen-opcode:
	@$(r6rs) ./scheme/gen-header.scm ./opcodes.h
