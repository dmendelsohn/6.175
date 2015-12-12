#*****************************************************************************
# bpred_ras.S
#-----------------------------------------------------------------------------
# branch prediction micro benchmark
# This benchmark stress tests return address stacks

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        // Cycle count register
        mfc0 $28, $10

        // Return register
        li $30, 1

        // Start test
        jal f1

        // Finish test
        // Get cycle count
        mfc0 $29, $10

        // Do cycle subtraction
        // $29 = $29 - $28
        subu $29, $29, $28

        // Write cycle count as integer
        mtc0 $29, $18

        // Write new line (0x0A) as character
        li $29, 10
        mtc0 $29, $19

        // Finish with code from register $30
        mtc0 $30, $21

1:
        // Loop forever
        beq $0, $0, 1b

f1:
        addiu $2, $31, 0
        li $30, 2
        jal f2
        li $30, 7
        jal f2
        addiu $31, $2, 0
        jr $31

f2:
        addiu $3, $31, 0
        li $30, 3
        jal f3
        li $30, 8
        jal f3
        addiu $31, $3, 0
        jr $31

f3:
        addiu $4, $31, 0
        li $30, 4
        jal f4
        li $30, 9
        jal f4
        addiu $31, $4, 0
        jr $31

f4:
        addiu $5, $31, 0
        li $30, 5
        jal f5
        li $30, 10
        jal f5
        addiu $31, $5, 0
        jr $31

f5:
        addiu $6, $31, 0
        li $30, 6
        jal f6
        li $30, 11
        jal f6
        addiu $31, $6, 0
        jr $31

f6:
        li $30, 0
        jr $31

fail:
        // Fail with code 12
        li $30, 12
        mtc0 $30, $21

2:
        // Loop forever
        beq $0, $0, 2b
