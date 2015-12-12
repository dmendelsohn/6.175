#*****************************************************************************
# smipsv2_bgtz.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_bgtz.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test bgtz instruction.
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
        
        TEST_BR1_OP_TAKEN( 2, bgtz, 1 );
        TEST_BR1_OP_TAKEN( 3, bgtz, 10 );
                
        TEST_BR1_OP_NOTTAKEN( 4, bgtz, 0  );
        TEST_BR1_OP_NOTTAKEN( 5, bgtz, -1 );

        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_BR1_SRC1_BYPASS( 6, 0, bgtz, -1 );
        TEST_BR1_SRC1_BYPASS( 7, 1, bgtz, -1 );
        TEST_BR1_SRC1_BYPASS( 8, 2, bgtz, -1 );

        #-------------------------------------------------------------
        # Test delay slot instructions not executed nor bypassed
        #-------------------------------------------------------------
        
        TEST_CASE( 9, $2, 3, \
          li $2, 1; \
          bgtz $2, 1f; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
          addiu $2, 1; \
      1:  addiu $2, 1; \
          addiu $2, 1; \
        )                     
                
        TEST_PASSFAIL

