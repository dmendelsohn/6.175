#*****************************************************************************
# smipsv1_bne.S
#-----------------------------------------------------------------------------
# $Id: smipsv1_bne.S,v 1.1.1.1 2006/02/20 03:53:12 cbatten Exp $
#
#  Test bne instruction
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:        
        
        # Test 1: Taken?

        addiu $2, $0, 1
        addiu $3, $0, 2
        bne   $2, $3, 1f
        bne   $0, $2, fail
1:

        # Test 2: Not taken?

        addiu $2, $0, 1
        addiu $3, $0, 1
        bne   $2, $3, fail
        
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


        

