        .globl  main
        .globl  __testcode

//#include <regdef.h>

/* These are not normally available for user mode programs-however,
   we want to use them in test programs */

#define TEST_SMIPSRAW
 # Status reg. mask for IM_HOST | IM_EXTINT0 | IM_EXTINT1 | IEP
#define __TESTSTATUS 0x00005804

        .globl  __teststatus
        .data   99
__teststatus:
        .word   __TESTSTATUS

        .globl  __TESTDATABEGIN

#define TEST_DATABEGIN                  \
        .data 1;                        \
        .align  4;                      \
__TESTDATABEGIN:


        .globl  __TESTDATAEND

#define TEST_DATAEND                    \
__TESTDATAEND:

        .data 2
__testsentinel:
        .word   0xdeadbeef

#define SYNC nop; nop

#define TEST_CRASH                      \
        break

#define TEST_DONE                       \
        SYNC;                           \
        li      t0, TOHOST_HALTED;      \
        .set    noat;                   \
        mtc0    t0, $21;                \
        .set    at;                     \
1:      b       1b

/* Output a word in a0 to the SIP port - potentially destroys t0-t9, v0-v1 */

#define TEST_OUTPUT_A0			\
	la	t0, __testoutput;	\
	jalr	t0

#define TEST_CODEBEGIN                  \
        .text;                          \
        .ent    __testcode;             \
__testcode:;                            \
__start:

        

#define TEST_CODEEND                    \
        .end    __testcode;             \
        TEST_DONE

	.data
	.align 2
ptab:	.word 0x00000000
	.word 0x00000001
	.word 0x00000002
	.word 0x00000003
	.word 0x00000004
	.word 0x00000005
	.word 0x00000006
	.word 0x00000007
	.word 0x00000008

