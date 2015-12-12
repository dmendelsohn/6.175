#*****************************************************************************
# smipsv2_jal.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_jal.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test jal instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Test 2: Basic test
        #-------------------------------------------------------------

test_2:        
        li $30, 2
        li $31, 0
        
linkaddr_2:      
        jal target_2
        nop
        nop
        
        j fail 

target_2: 
        la $2, linkaddr_2
        addiu $2, $2, 4
        bne $2, $31, fail

        #-------------------------------------------------------------
        # Test delay slot instructions not executed nor bypassed
        #-------------------------------------------------------------
        
        TEST_CASE( 3, $2, 3, \
          li $2, 1; \
          jal 1f; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
      1:  addiu $2, 1; \
          addiu $2, 1; \
        )                             
        
        TEST_PASSFAIL

