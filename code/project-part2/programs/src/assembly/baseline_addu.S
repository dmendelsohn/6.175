#*****************************************************************************
# baseline_addu.S
#-----------------------------------------------------------------------------
# micro benchmark to compute the execution time of 100 addu instructions

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        // Cycle count register
        mfc0 $28, $10

        // Return register
        li $30, 0

        // i = 0
        li $8, 0
        // j = 0
        li $9, 0

        // Start test
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        // i++ x5
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        addiu $8, $8, 1
        // j++ x5
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1
        addiu $9, $9, 1

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

        // error code = (i + j) - 100
        addu $10, $8, $9
        addiu $30, $10, -100

        // Finish with code from register $30
        mtc0 $30, $21

1:
        // Loop forever
        j 1b
