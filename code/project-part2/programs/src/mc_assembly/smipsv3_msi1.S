#*****************************************************************************
# smipsv3_msi1.S
#-----------------------------------------------------------------------------
# Very simple msi test. core 0 and core 1 are looking at independent cache
# lines.
#

#include "smipstest.h"

TEST_SMIPSRAW

        .text
main:
        mfc0  $2, $15
        addiu $3, $0, 1
        beq   $2, $0, main0
        beq   $2, $3, main1
        # In case there are more than 2 cores
        j     pass

main0:
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

        # Read hit
        lw    $3, 0x0004($2)
        addiu $4, $0, 0x0F01
        addiu $8, $0, 2
        bne   $4, $3, fail



        # Now lets add 0x00F0 to each entry in the current cache line
        # Read hit
        lw    $3, 0x0000($2)
        addiu $3, $3, 0x00F0
        # S -> M
        sw    $3, 0x0000($2)

        # Read/Write hit
        lw    $3, 0x0004($2)
        addiu $3, $3, 0x00F0
        sw    $3, 0x0004($2)



        # Now read from another cache line to evect the current cache line
        # M -> I -> S
        lw    $3, 0x2000($2)
        addiu $4, $0, 0x0000
        addiu $8, $0, 3
        bne   $4, $3, fail

        # Read hit
        lw    $3, 0x2004($2)
        addiu $4, $0, 0x0001
        addiu $8, $0, 4
        bne   $4, $3, fail



        # Now read the main cache line to check the previous additions
        # S -> I -> S
        lw    $3, 0x0000($2)
        addiu $4, $0, 0x0FF0
        addiu $8, $0, 5
        bne   $4, $3, fail

        # Read hit
        lw    $3, 0x0004($2)
        addiu $4, $0, 0x0FF1
        addiu $8, $0, 6
        bne   $4, $3, fail







        # If we get here then we passed
        addiu $2, $0, 1
        bne   $0, $2, pass
        addiu $8, $0, 7



main1:
        # Look at address 0x4020
        addiu $2, $0, 0x4020



        # Store some data into a single cache line
        # I -> M
        addiu $3, $0, 0x1F00
        sw    $3, 0x0000($2)

        # Write hit
        addiu $3, $0, 0x1F01
        sw    $3, 0x0004($2)



        # Now store some data into another cache line with the same index
        # M -> I -> M
        addiu $3, $0, 0x1000
        sw    $3, 0x2000($2)

        # Write hit
        addiu $3, $0, 0x1001
        sw    $3, 0x2004($2)



        # Now read the data
        # M -> I -> S
        lw    $3, 0x0000($2)
        addiu $4, $0, 0x1F00
        addiu $8, $0, 1
        bne   $4, $3, fail

        # Read hit
        lw    $3, 0x0004($2)
        addiu $4, $0, 0x1F01
        addiu $8, $0, 2
        bne   $4, $3, fail



        # Now lets add 0x00F0 to each entry in the current cache line
        # Read hit
        lw    $3, 0x0000($2)
        addiu $3, $3, 0x00F0
        # S -> M
        sw    $3, 0x0000($2)

        # Read/Write hit
        lw    $3, 0x0004($2)
        addiu $3, $3, 0x00F0
        sw    $3, 0x0004($2)



        # Now read from another cache line to evect the current cache line
        # M -> I -> S
        lw    $3, 0x2000($2)
        addiu $4, $0, 0x1000
        addiu $8, $0, 3
        bne   $4, $3, fail

        # Read hit
        lw    $3, 0x2004($2)
        addiu $4, $0, 0x1001
        addiu $8, $0, 4
        bne   $4, $3, fail



        # Now read the main cache line to check the previous additions
        # S -> I -> S
        lw    $3, 0x0000($2)
        addiu $4, $0, 0x1FF0
        addiu $8, $0, 5
        bne   $4, $3, fail

        # Read hit
        lw    $3, 0x0004($2)
        addiu $4, $0, 0x1FF1
        addiu $8, $0, 6
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

        #-------------------------------------------------------------
        # Test data
        #-------------------------------------------------------------

        .data
tdat:
tdat1:  .word 0x000000ff
tdat2:  .word 0x00007f00
tdat3:  .word 0x00000ff0
tdat4:  .word 0x0000700f

