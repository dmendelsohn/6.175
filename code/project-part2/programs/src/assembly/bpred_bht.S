#*****************************************************************************
# bpred_bht.S
#-----------------------------------------------------------------------------
# branch prediction micro benchmark
# A bht will improve the prediction of branches 1-4 over just a btb

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        // Cycle count register
        mfc0 $28, $10

        // Return register
        li $30, 0

        // Start test
        // i = 100
        li $8, 100
        // count = 0
        li $11, 0

loopstart:
        // x = i & 0x03
        andi $9, $8, 3

        // if (x != 0) count++
        li $10, 0
1:      beq $9, $10, skip0
        addiu $11, $11, 1
skip0:
        // if (x != 1) count++
        li $10, 1
2:      beq $9, $10, skip1
        addiu $11, $11, 1
skip1:
        // if (x != 2) count++
        li $10, 2
3:      beq $9, $10, skip2
        addiu $11, $11, 1
skip2:
        // if (x != 3) count++
        li $10, 3
4:      beq $9, $10, skip3
        addiu $11, $11, 1
skip3:

        // i = i - 1
        addiu $8, $8, -1

        // if (i != 0) goto loopstart
        bne $8, $0, loopstart


        // set $30 to x if x != 300
        li $12, 300
        beq $11, $12, success
        addiu $30, $11, 0

success:

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

        // Loop forever
        beq $0, $0, 1b
