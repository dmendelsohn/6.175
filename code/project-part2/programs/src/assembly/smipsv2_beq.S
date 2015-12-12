#*****************************************************************************
# smipsv2_beq.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_beq.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test beq instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Branch tests
        #-------------------------------------------------------------

        # Each test checks both forward and backward branches
        
        TEST_BR2_OP_TAKEN( 2, beq,  0,  0 );
        TEST_BR2_OP_TAKEN( 3, beq,  1,  1 );
        TEST_BR2_OP_TAKEN( 4, beq, -1, -1 );

        TEST_BR2_OP_NOTTAKEN( 5, beq,  0,  1 );
        TEST_BR2_OP_NOTTAKEN( 6, beq,  1,  0 );
        TEST_BR2_OP_NOTTAKEN( 7, beq, -1,  1 );
        TEST_BR2_OP_NOTTAKEN( 8, beq,  1, -1 );
                                        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_BR2_SRC12_BYPASS( 9,  0, 0, beq, 0, -1 );
        TEST_BR2_SRC12_BYPASS( 10, 0, 1, beq, 0, -1 );        
        TEST_BR2_SRC12_BYPASS( 11, 0, 2, beq, 0, -1 );
        TEST_BR2_SRC12_BYPASS( 12, 1, 0, beq, 0, -1 );
        TEST_BR2_SRC12_BYPASS( 13, 1, 1, beq, 0, -1 );        
        TEST_BR2_SRC12_BYPASS( 14, 2, 0, beq, 0, -1 );

        TEST_BR2_SRC12_BYPASS( 15, 0, 0, beq, 0, -1 );
        TEST_BR2_SRC12_BYPASS( 16, 0, 1, beq, 0, -1 );        
        TEST_BR2_SRC12_BYPASS( 17, 0, 2, beq, 0, -1 );
        TEST_BR2_SRC12_BYPASS( 18, 1, 0, beq, 0, -1 );
        TEST_BR2_SRC12_BYPASS( 19, 1, 1, beq, 0, -1 );        
        TEST_BR2_SRC12_BYPASS( 20, 2, 0, beq, 0, -1 );                        

        #-------------------------------------------------------------
        # Test delay slot instructions not executed nor bypassed
        #-------------------------------------------------------------
        
        TEST_CASE( 21, $2, 3, \
          li $2, 1; \
          beq $0, $0, 1f; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
      1:  addiu $2, 1; \
          addiu $2, 1; \
        )                     
                
        TEST_PASSFAIL

