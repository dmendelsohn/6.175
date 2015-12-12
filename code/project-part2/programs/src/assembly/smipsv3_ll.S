#*****************************************************************************
# smipsv1_ll.S
#-----------------------------------------------------------------------------
# Test ll instruction.
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:        
        
        # Test 1: Load some data

        addiu $2, $0, %lo(tdat)

        ll    $3, 0($2)
        addiu $4, $0, 0x00ff
        bne   $4, $3, fail
        
        ll    $3, 4($2)
        addiu $4, $0, 0x7f00
        bne   $4, $3, fail
        
        ll    $3, 8($2)
        addiu $4, $0, 0x0ff0
        bne   $4, $3, fail
        
        ll    $3, 12($2)
        addiu $4, $0, 0x700f
        bne   $4, $3, fail

        # Test 2: Load some data with negative offsets

        addiu $2, $0, %lo(tdat4)

        ll    $3, -12($2)
        addiu $4, $0, 0x00ff
        bne   $4, $3, fail
        
        ll    $3, -8($2)
        addiu $4, $0, 0x7f00
        bne   $4, $3, fail
        
        ll    $3, -4($2)
        addiu $4, $0, 0x0ff0
        bne   $4, $3, fail
        
        ll    $3, 0($2)
        addiu $4, $0, 0x700f
        bne   $4, $3, fail
                
        # If we get here then we passed

        addiu $2, $0, 1
        bne   $0, $2, pass
        
fail:          
        addiu $2, $0, 1
        mtc0  $2, $21      
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
                
                            

        

