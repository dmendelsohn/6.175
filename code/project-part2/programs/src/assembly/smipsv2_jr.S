#*****************************************************************************
# smipsv2_jr.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_jr.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test jr instruction.
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
        la $3, target_2
        
linkaddr_2:
        jr $3
        nop
        nop
        
        j fail

target_2:

        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_JR_SRC1_BYPASS( 3, 0, jr );
        TEST_JR_SRC1_BYPASS( 4, 1, jr );                
        TEST_JR_SRC1_BYPASS( 5, 2, jr );        

        #-------------------------------------------------------------
        # Test delay slot instructions not executed nor bypassed
        #-------------------------------------------------------------
        
        TEST_CASE( 6, $2, 3, \
          li $2, 1; \
          la $3, 1f;       
          jr $3; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
      1:  addiu $2, 1; \
          addiu $2, 1; \
        )                             
        
                
        TEST_PASSFAIL

