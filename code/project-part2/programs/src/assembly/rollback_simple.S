#*****************************************************************************
# baseline.S
#-----------------------------------------------------------------------------
# micro benchmark to compute the execution time of 100 nop instructions

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:
        // Return register
        li $30, 0

        // Data
        li $4, 1
        li $5, 1
        li $6, 16

        // Start test
        addu $4, $4, $4
        addu $4, $4, $4
        addu $4, $4, $4
        addu $4, $4, $4
        beq $4, $6, check

        // At the very least, rename register 4
        li $4, 0

        // 32 nop's to fill rob
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop

check:
        addu $5, $4, $0
        beq $5, $6, success

fail:
        li $31, 1

success:
        // Finish with code from register $30
        mtc0 $30, $21

1:
        // Loop forever
        beq $0, $0, 1b
