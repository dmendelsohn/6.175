#*****************************************************************************
# baseline.S
#-----------------------------------------------------------------------------
# micro benchmark to compute the execution time of 100 nop instructions

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
        nop
        nop
        nop
        nop

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

1:
        // Loop forever
        beq $0, $0, 1b
