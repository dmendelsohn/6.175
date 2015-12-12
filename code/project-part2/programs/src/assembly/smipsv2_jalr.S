#*****************************************************************************
# smipsv2_jalr.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_jalr.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test jalr instruction.
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
        jalr $16, $3
        nop
        nop
        
        j fail 

target_2: 
        la $2, linkaddr_2
        addiu $2, $2, 4
        bne $2, $16, fail

        #-------------------------------------------------------------
        # Test 3: Check r0 target and that r31 is not modified
        #-------------------------------------------------------------

test_3:        
        li $30, 3
        li $31, 0
        la $4, target_3

linkaddr_3:   
        jalr $0, $4
        nop
                
        j fail 

target_3: 
        bne $31, $0, fail

        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_JALR_SRC1_BYPASS( 4, 0, jalr );
        TEST_JALR_SRC1_BYPASS( 5, 1, jalr );                
        TEST_JALR_SRC1_BYPASS( 6, 2, jalr );

        #-------------------------------------------------------------
        # Test delay slot instructions not executed nor bypassed
        #-------------------------------------------------------------
        
        TEST_CASE( 7, $2, 3, \
          li $2, 1; \
          la $3, 1f;
          jalr $16, $3; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
      1:  addiu $2, 1; \
          addiu $2, 1; \
        )                             
                
        TEST_PASSFAIL

