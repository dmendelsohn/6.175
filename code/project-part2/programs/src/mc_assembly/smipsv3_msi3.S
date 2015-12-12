#*****************************************************************************
# smipsv3_msi3.S
#-----------------------------------------------------------------------------
# A more much complex multicore assembly test for MSI. This uses a wait
# function to (hopefully) force desired timing characteristics between the two
# threads. Error codes 10x denote timing errors. All other error codes are
# functional problems.
#
# To make reading (and writing) the source code more exciting, all the data
# used in this program are production codes for Simpsons episodes.
#
# ep 4F24 - "Lisa the Simpson"
# ep 9F10 - "Marge vs. the Monorail"
# ep 2F16 - "Who Shot Mr. Burns (Part One)"
# ep 9F07 - "Mr. Plow"
# ep 2F20 - "Who Shot Mr. Burns (Part Two)"
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
        # Look at addresses 0x4000 and 0x4040
        # 0x4000 is shared data
        # 0x4040 is for synchronization
        addiu $2, $0, 0x4000
        addiu $3, $0, 0x4040

        # Stage 1
        ##########


        # Store to address 0x4000 and remove it from core0s L1 cache
        addiu $4, $0, 0x4F24 # "Lisa the Simpson"
        # I -> M
        sw    $4, 0x0000($2)
        # M -> I -> S
        lw    $4, 0x2000($2)

        # Now let core 1 know we are done
        addiu $4, $0, 0x0001
        # I -> M
        sw    $4, 0x0000($3)
        # M -> I -> S
        # Forces the update of DRAM
        lw    $4, 0x2000($3)

        jal   wait

        # Stage 2
        ##########

        jal   wait

        # Stage 3
        ##########

        # Make sure core 1 actually finished stage 2
        lw    $4, 0x0000($3)
        addiu $5, $0, 0x0002
        addiu $8, $0, 102
        bne   $4, $5, fail

        # Now write some new data to 0x4000
        # This will have to downgrade core 1 from S to I
        addiu $4, $0, 0x9F10 # "Marge vs. the Monorail"
        sw    $4, 0x0000($2)
        # Force the update of DRAM
        lw    $4, 0x2000($2)

        # Now let core 0 know we are done
        addiu $4, $0, 0x0003
        sw    $4, 0x0000($3)
        # Forces the update of DRAM
        lw    $4, 0x2000($3)

        jal   wait

        # Stage 4
        ##########

        jal   wait
        
        # Stage 5
        ##########

        # Make sure core 1 actually finished stage 4
        lw    $4, 0x0000($3)
        addiu $5, $0, 0x0004
        addiu $8, $0, 104
        bne   $4, $5, fail

        # Now write some new data to 0x4000
        # This will have to downgrade core 1 from S to I
        addiu $4, $0, 0x2F16 # "Who Shot Mr. Burns (Part One)"
        sw    $4, 0x0000($2)
        # Core 1 will force core 0 to downgrade from M to I in stage 6 to see
        # the change in data

        # Now let core 0 know we are done
        addiu $4, $0, 0x0005
        sw    $4, 0x0000($3)
        # Forces the update of DRAM
        lw    $4, 0x2000($3)

        jal   wait

        # Stage 6
        ##########

        jal   wait
        
        # Stage 7
        ##########

        # Make sure core 1 actually finished stage 6
        lw    $4, 0x0000($3)
        addiu $5, $0, 0x0006
        addiu $8, $0, 106
        bne   $4, $5, fail

        # Now write some new data to 0x4000
        # This will have to downgrade core 1 from M to I
        addiu $4, $0, 0x2F20 # "Who Shot Mr. Burns (Part Two)"
        sw    $4, 0x0000($2)

        # Now let core 0 know we are done
        addiu $4, $0, 0x0007
        sw    $4, 0x0000($3)
        # Forces the update of DRAM
        lw    $4, 0x2000($3)



        # If we get here then we passed
        addiu $2, $0, 1
        bne   $0, $2, pass

main1:
        # Also look at addresses 0x4000 and 0x4040
        # 0x4000 is shared data
        # 0x4040 is for synchronization
        addiu $2, $0, 0x4000
        addiu $3, $0, 0x4040


        # Stage 1
        ##########
        jal wait

        # Stage 2
        ##########

        # Make sure core 0 actually finished stage 1
        lw    $4, 0x0000($3)
        addiu $5, $0, 0x0001
        addiu $8, $0, 101
        bne   $4, $5, fail

        # Now make sure the correct data was written
        lw    $4, 0x0000($2)
        addiu $5, $0, 0x4F24 # "Lisa the Simpson"
        addiu $8, $0, 1
        bne   $4, $5, fail
        # Core 1 will keep 0x4000 in its cache so Core 0 will have to evict it

        # Now let core 0 know we are done
        addiu $4, $0, 0x0002
        sw    $4, 0x0000($3)
        # Forces the update of DRAM
        lw    $4, 0x2000($3)

        jal wait

        # Stage 3
        ##########

        jal wait

        # Stage 4
        ##########

        # Make sure core 0 actually finished stage 3
        lw    $4, 0x0000($3)
        addiu $5, $0, 0x0003
        addiu $8, $0, 103
        bne   $4, $5, fail

        # Now make sure the correct data was written
        lw    $4, 0x0000($2)
        addiu $5, $0, 0x9F10 # "Marge vs. the Monorail"
        addiu $8, $0, 3
        bne   $4, $5, fail
        # Core 1 will keep 0x4000 in its cache so Core 0 will have to evict it

        # Now let core 0 know we are done
        addiu $4, $0, 0x0004
        sw    $4, 0x0000($3)
        # Forces the update of DRAM
        lw    $4, 0x2000($3)

        jal wait

        # Stage 5
        ##########

        jal wait

        # Stage 6
        ##########

        # Make sure core 0 actually finished stage 5
        lw    $4, 0x0000($3)
        addiu $5, $0, 0x0005
        addiu $8, $0, 105
        bne   $4, $5, fail

        # Now make sure the correct data was written
        lw    $4, 0x0000($2)
        addiu $5, $0, 0x2F16 # "Who Shot Mr. Burns (Part One)"
        addiu $8, $0, 5
        bne   $4, $5, fail

        # Lets write something to get this cache line to M
        addiu $4, $0, 0x9F07 # "Mr. Plow"
        sw    $4, 0x0000($2)
        
        # Now let core 0 know we are done
        addiu $4, $0, 0x0006
        sw    $4, 0x0000($3)
        # Forces the update of DRAM
        lw    $4, 0x2000($3)

        jal wait

        # Stage 7
        ##########

        jal wait

        # Stage 8
        ##########

        # Make sure core 0 actually finished stage 7
        lw    $4, 0x0000($3)
        addiu $5, $0, 0x0007
        addiu $8, $0, 107
        bne   $4, $5, fail

        # Now make sure the correct data was written
        lw    $4, 0x0000($2)
        addiu $5, $0, 0x2F20 # "Who Shot Mr. Burns (Part Two)"
        addiu $8, $0, 7
        bne   $4, $5, fail



        # If we get here then we passed
        addiu $2, $0, 1
        bne   $0, $2, pass
        addiu $8, $0, 8

fail:          
        mtc0  $8, $21      
1:      beq   $0, $0, 1b    

pass:      
        mtc0  $0, $21       
1:      beq   $0, $0, 1b    
                            
wait:
        # do nothing for 256 loop iterations
        addiu $9, $0, 0x0000
        addiu $10, $0, 0x0100
lp:
        addiu $9, $9, 0x0001
        bne   $9, $10, lp
        jr    $31

        #-------------------------------------------------------------
        # Test data
        #-------------------------------------------------------------

        .data
tdat:
tdat1:  .word 0x000000ff
tdat2:  .word 0x00007f00        
tdat3:  .word 0x00000ff0
tdat4:  .word 0x0000700f

