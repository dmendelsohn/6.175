#*****************************************************************************
# smipsv3_lw.S
#-----------------------------------------------------------------------------
# Test lw instruction assuming a cache.
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:
        // $2 = coreid
        mfc0  $2, $15
        // $2 = $2 * 64
        sll   $2, $2, 6
        // Look at address 0x4000 + 0x40 * coreid
        addiu $2, $2, 0x4000

        // Store some data into a single cache line
        // I -> M
        addiu $3, $0, 0x1F00
        sw    $3, 0x0000($2)

        // Now store some data into another cache line with the same index
        addiu $3, $0, 0x1000
        sw    $3, 0x2000($2)

        // Now do a load linked instruction for 0x4000
        ll    $3, 0x0000($2)
        // Add 0x00FF to the already existing 0x1F00
        addiu $3, $3, 0x00FF
        // Store 0x1FFF into 0x4000
        sc    $3, 0x0000($2)
        // $3 now contains 1 if the store conditional was successful (which it should be)

        // Return error code 1 if the store conditional was not successful
        addiu $4, $0, 1
        addiu $8, $0, 1
        bne   $3, $4, fail

        // Return error code 2 if the correct data wasn't stored
        lw    $3, 0x0000($2)
        addiu $4, $0, 0x1FFF
        addiu $8, $0, 2
        bne   $3, $4, fail

        // Do a load linked instruction for 0x4000
        ll    $3, 0x0000($2)
        // Break the link by loading another line
        lw    $4, 0x2000($2)
        // Add 1 to the data from 0x4000
        addiu $3, $3, 1
        // Try to store it conditionally (this should fail)
        sc    $3, 0x0000($2)

        // Return error code 3 if the store conditional was successful
        addiu $8, $0, 3
        addiu $4, $0, 0
        bne   $3, $4, fail
        
        // Return error code 4 if the data was changed
        lw    $3, 0x0000($2)
        addiu $4, $0, 0x1FFF
        addiu $8, $0, 4
        bne   $3, $4, fail

        // If we get here then we passed
        addiu $2, $0, 1
        bne   $0, $2, pass
        addiu $8, $0, 5

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

