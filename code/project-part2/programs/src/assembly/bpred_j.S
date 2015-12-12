#*****************************************************************************
# bpred_j.S
#-----------------------------------------------------------------------------
# branch prediction micro benchmark

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
        j   step1
        li $30, 1
step1:  j   step2
        li $30, 2
step2:  j   step3
        li $30, 3
step3:  j   step4
        li $30, 4
step4:  j   step5
        li $30, 5
step5:  j   step6
        li $30, 6
step6:  j   step7
        li $30, 7
step7:  j   step8
        li $30, 8
step8:  j   step9
        li $30, 9
step9:  j   step10
        li $30, 10
step10: j   step11
        li $30, 11
step11: j   step12
        li $30, 12
step12: j   step13
        li $30, 13
step13: j   step14
        li $30, 14
step14: j   step15
        li $30, 15
step15: j   step16
        li $30, 16

        // Get cycle count
step16: mfc0 $29, $10

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
