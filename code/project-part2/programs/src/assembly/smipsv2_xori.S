#*****************************************************************************
# smipsv2_xori.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_xori.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test xori instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Logical tests
        #-------------------------------------------------------------
         
        TEST_IMM_OP( 2, xori, 0xff00f00f, 0xff00ff00, 0x0f0f );
        TEST_IMM_OP( 3, xori, 0x0ff0ff00, 0x0ff00ff0, 0xf0f0 );
        TEST_IMM_OP( 4, xori, 0x00ff0ff0, 0x00ff00ff, 0x0f0f );
        TEST_IMM_OP( 5, xori, 0xf00f00ff, 0xf00ff00f, 0xf0f0 );

        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_IMM_SRC1_EQ_DEST( 6, xori, 0xff00f00f, 0xff00ff00, 0x0f0f );
                        
         #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_IMM_DEST_BYPASS( 7,  0, xori, 0x0ff0ff00, 0x0ff00ff0, 0xf0f0 );
        TEST_IMM_DEST_BYPASS( 8,  1, xori, 0x00ff0ff0, 0x00ff00ff, 0x0f0f );
        TEST_IMM_DEST_BYPASS( 9,  2, xori, 0xf00f00ff, 0xf00ff00f, 0xf0f0 );
        
        TEST_IMM_SRC1_BYPASS( 10, 0, xori, 0x0ff0ff00, 0x0ff00ff0, 0xf0f0 );
        TEST_IMM_SRC1_BYPASS( 11, 1, xori, 0x00ff0ff0, 0x00ff00ff, 0x0f0f );
        TEST_IMM_SRC1_BYPASS( 12, 2, xori, 0xf00f00ff, 0xf00ff00f, 0xf0f0 );

        TEST_PASSFAIL

