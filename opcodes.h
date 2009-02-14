#ifndef OPCODES_H
#define OPCODES_H

/* Generated by gen-header.scm, do not edit. */

#define LOAD_FUNC	0	/* Load function local to module */
#define LOAD_PARENT	1	/* Load object from parent env */
#define LOAD_LOCAL	2	/* Load object from frame-local area */
#define LOAD_SYM	3	/* Load predefined symbol local to module */
#define LOAD_IMPORT	4	/* Load object from module import table */
#define JUMP_IF_FALSE	5	/* Jump if false */
#define JUMP_IF_TRUE	6	/* Jump if true */
#define JUMP_FORWARD	7	/* Jump forward */
#define FUNC_CALL	8	/* Call function */
#define RETURN	9	/* Return from function */
#define SET_LOCAL	10	/* Assign new value to local binding */
#define ARITH_ADD	11	/* Add numbers */
#define ARITH_SUB	12	/* Substitute numbers */
#define ARITH_MUL	13	/* Multiply numbers */
#define ARITH_DIV	14	/* Divide numbers */

#define OP_CASE(code) case code: return #code

const char* opcode_name(int code)
{
	switch (code) {
		OP_CASE(LOAD_FUNC);
		OP_CASE(LOAD_PARENT);
		OP_CASE(LOAD_LOCAL);
		OP_CASE(LOAD_SYM);
		OP_CASE(LOAD_IMPORT);
		OP_CASE(JUMP_IF_FALSE);
		OP_CASE(JUMP_IF_TRUE);
		OP_CASE(JUMP_FORWARD);
		OP_CASE(FUNC_CALL);
		OP_CASE(RETURN);
		OP_CASE(SET_LOCAL);
		OP_CASE(ARITH_ADD);
		OP_CASE(ARITH_SUB);
		OP_CASE(ARITH_MUL);
		OP_CASE(ARITH_DIV);
	}
	return "unknown";
}

#endif