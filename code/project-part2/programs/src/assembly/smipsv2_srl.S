#*****************************************************************************
# smipsv2_srl.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_srl.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test srl instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------

        TEST_IMM_OP( 2,  srl, 0x80000000, 0x80000000, 0  );
        TEST_IMM_OP( 3,  srl, 0x40000000, 0x80000000, 1  );
        TEST_IMM_OP( 4,  srl, 0x01000000, 0x80000000, 7  );        
        TEST_IMM_OP( 5,  srl, 0x00020000, 0x80000000, 14 );
        TEST_IMM_OP( 6,  srl, 0x00000001, 0x80000001, 31 );

        TEST_IMM_OP( 7,  srl, 0xffffffff, 0xffffffff, 0  );
        TEST_IMM_OP( 8,  srl, 0x7fffffff, 0xffffffff, 1  );
        TEST_IMM_OP( 9,  srl, 0x01ffffff, 0xffffffff, 7  );
        TEST_IMM_OP( 10, srl, 0x0003ffff, 0xffffffff, 14 );
        TEST_IMM_OP( 11, srl, 0x00000001, 0xffffffff, 31 );

        TEST_IMM_OP( 12, srl, 0x21212121, 0x21212121, 0  );
        TEST_IMM_OP( 13, srl, 0x10909090, 0x21212121, 1  );
        TEST_IMM_OP( 14, srl, 0x00424242, 0x21212121, 7  );
        TEST_IMM_OP( 15, srl, 0x00008484, 0x21212121, 14 );
        TEST_IMM_OP( 16, srl, 0x00000000, 0x21212121, 31 );

        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_IMM_SRC1_EQ_DEST( 17, srl, 0x01000000, 0x80000000, 7 );
        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_IMM_DEST_BYPASS( 18, 0, srl, 0x01000000, 0x80000000, 7  );
        TEST_IMM_DEST_BYPASS( 19, 1, srl, 0x00020000, 0x80000000, 14 );
        TEST_IMM_DEST_BYPASS( 20, 2, srl, 0x00000001, 0x80000001, 31 );

        TEST_IMM_SRC1_BYPASS( 21, 0, srl, 0x01000000, 0x80000000, 7  );
        TEST_IMM_SRC1_BYPASS( 22, 1, srl, 0x00020000, 0x80000000, 14 );        
        TEST_IMM_SRC1_BYPASS( 23, 2, srl, 0x00000001, 0x80000001, 31 );
        
        TEST_PASSFAIL

