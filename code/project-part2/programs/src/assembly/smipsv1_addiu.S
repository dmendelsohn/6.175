#*****************************************************************************
# smipsv1_addiu.S
#-----------------------------------------------------------------------------
# $Id: smipsv1_addiu.S,v 1.1.1.1 2006/02/20 03:53:12 cbatten Exp $
#
#  Test addiu instruction
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:        
        
        # Test 1: 1 + 1 = 2

        addiu $2, $0, 1
        addiu $3, $2, 1
        addiu $4, $0, 2
        bne   $4, $3, fail

        # Test 2: 0x0fff + 0x0001 = 0x1000

        addiu $2, $0, 0x0fff
        addiu $3, $2, 0x0001
        addiu $4, $0, 0x1000
        bne   $4, $3, fail

        # Test 3: 0xffff + 0x0001 = 0x0000

        addiu $2, $0, 0xffff
        addiu $3, $2, 0x0001
        bne   $0, $3, fail

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

                            

        

