#*****************************************************************************
# smipsv3_lw.S
#-----------------------------------------------------------------------------
# Test lw instruction assuming a cache.
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:        
        
        # Look at address 0x4000
        addiu $2, $0, 0x4000



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

