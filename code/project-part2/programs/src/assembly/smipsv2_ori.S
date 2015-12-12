#*****************************************************************************
# smipsv2_ori.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_ori.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test ori instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Logical tests
        #-------------------------------------------------------------
         
        TEST_IMM_OP( 2, ori, 0xff00ff0f, 0xff00ff00, 0x0f0f );
        TEST_IMM_OP( 3, ori, 0x0ff0fff0, 0x0ff00ff0, 0xf0f0 );
        TEST_IMM_OP( 4, ori, 0x00ff0fff, 0x00ff00ff, 0x0f0f );
        TEST_IMM_OP( 5, ori, 0xf00ff0ff, 0xf00ff00f, 0xf0f0 );

        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_IMM_SRC1_EQ_DEST( 6, ori, 0xff00fff0, 0xff00ff00, 0xf0f0 );
                        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_IMM_DEST_BYPASS( 7,  0, ori, 0x0ff0fff0, 0x0ff00ff0, 0xf0f0 );
        TEST_IMM_DEST_BYPASS( 8,  1, ori, 0x00ff0fff, 0x00ff00ff, 0x0f0f );
        TEST_IMM_DEST_BYPASS( 9,  2, ori, 0xf00ff0ff, 0xf00ff00f, 0xf0f0 );
        
        TEST_IMM_SRC1_BYPASS( 10, 0, ori, 0x0ff0fff0, 0x0ff00ff0, 0xf0f0 );
        TEST_IMM_SRC1_BYPASS( 11, 1, ori, 0x00ff0fff, 0x00ff00ff, 0x0f0f );
        TEST_IMM_SRC1_BYPASS( 12, 2, ori, 0xf00ff0ff, 0xf00ff00f, 0xf0f0 );
                        
        TEST_PASSFAIL

