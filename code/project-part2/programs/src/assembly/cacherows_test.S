#*****************************************************************************
# cacherows_test.S
#-----------------------------------------------------------------------------

#include "smipstest.h"
#include "test_macros.h"

TEST_SMIPSRAW

        .text
main:
        // Cycle count register
        mfc0 $28, $10

        // Return register
        li $30, 0

        # Look at address 0x4000
        addiu $2, $0, 0x4000



        # Store some data into a single cache line
        # I -> M
        addiu $3, $0, 0x0F00
        sw    $3, 0x0000($2)
# store 0x0F00 into 0x4000:
# cache miss
# send request to memory for address 4000 M state
# PPP:
# receive request for address 4000 M State,
# w 1 processor:
# rule 2 possible

# rule 2
# send request to memory
# receive data from memory
# update internal 0x4000 state
# send resp to cache w/ data

# cache:
# receive response to upgrade w/ data


        # Write hit
        addiu $3, $0, 0x0F01
        sw    $3, 0x0004($2)



        # Now store some data into another cache line with the same index
        # M -> I -> M
        addiu $3, $0, 0x0000
        sw    $3, 0x2000($2)

        # Write hit
        addiu $3, $0, 0x0001
        sw    $3, 0x2004($2)



        # Now read the data
        # M -> I -> S
        lw    $3, 0x0000($2)
        addiu $4, $0, 0x0F00
        addiu $8, $0, 1
        bne   $4, $3, fail

#        # Read hit
        lw    $3, 0x0004($2)
        addiu $4, $0, 0x0F01
        addiu $8, $0, 2
        bne   $4, $3, fail

        # If we get here then we passed
        addiu $2, $0, 1
        bne   $0, $2, pass
        addiu $8, $0, 7

fail:
        mtc0  $8, $21
1:      beq   $0, $0, 1b

pass:
        mtc0  $0, $21
1:      beq   $0, $0, 1b
