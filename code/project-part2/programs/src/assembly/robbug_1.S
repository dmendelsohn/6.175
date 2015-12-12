#*****************************************************************************
# robbug_1.S
#-----------------------------------------------------------------------------
# micro assembly test to force the head of the rob to mispredict and then
# commit the next instruction in the rob even though it is a wrong path
# instruction

#include "smipstest.h"
#include "test_macros.h"
                
        .text
main:
        // Return register
        li $30, 0

        // Address register
        addiu $2, $0, 0x4000

        // setting registers to 0
        // li $6, 0
        // li $7, 0
        // li $8, 0
        // li $9, 0

        // Interesting data
        li $4, 10
        li $5, 20

        // Initial branches to stress the mispredict fifo
        beq $4, $4, starttest
        beq $5, $5, starttest
        nop

starttest:
        // Start test
        sw $4, 0x0000($2)
        lw $3, 0x0000($2)
        beq $3, $4, check
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
        li $6, 1
        li $7, 1
        li $8, 1
        li $9, 1

check:
        addu $30, $6, $7
        addu $30, $30, $8
        addu $30, $30, $9

success:
        // Finish with code from register $30
        mtc0 $30, $21
        j end

1:
        // Loop forever
        beq $0, $0, 1b


fail:
        li $30, 1
        mtc0 $30, $21

2:
        // Loop forever
        beq $0, $0, 2b

