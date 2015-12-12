#*****************************************************************************
# smipsv2_blez.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_blez.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test blez instruction.
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
        
        TEST_BR1_OP_TAKEN( 2, blez, 0 );
        TEST_BR1_OP_TAKEN( 3, blez, -1 );
                
        TEST_BR1_OP_NOTTAKEN( 4, blez, 1  );
        TEST_BR1_OP_NOTTAKEN( 5, blez, 10 );

        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_BR1_SRC1_BYPASS( 6, 0, blez, 1 );
        TEST_BR1_SRC1_BYPASS( 7, 1, blez, 1 );                                        
        TEST_BR1_SRC1_BYPASS( 8, 2, blez, 1 );

        #-------------------------------------------------------------
        # Test delay slot instructions not executed nor bypassed
        #-------------------------------------------------------------
        
        TEST_CASE( 9, $2, 3, \
          li $2, 1; \
          blez $0, 1f; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
      1:  addiu $2, 1; \
          addiu $2, 1; \
        )                             
                
        TEST_PASSFAIL

