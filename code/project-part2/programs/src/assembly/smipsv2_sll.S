#*****************************************************************************
# smipsv2_sll.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_sll.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test sll instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------

        TEST_IMM_OP( 2,  sll, 0x00000001, 0x00000001, 0  );
        TEST_IMM_OP( 3,  sll, 0x00000002, 0x00000001, 1  );
        TEST_IMM_OP( 4,  sll, 0x00000080, 0x00000001, 7  );        
        TEST_IMM_OP( 5,  sll, 0x00004000, 0x00000001, 14 );
        TEST_IMM_OP( 6,  sll, 0x80000000, 0x00000001, 31 );

        TEST_IMM_OP( 7,  sll, 0xffffffff, 0xffffffff, 0  );
        TEST_IMM_OP( 8,  sll, 0xfffffffe, 0xffffffff, 1  );
        TEST_IMM_OP( 9,  sll, 0xffffff80, 0xffffffff, 7  );
        TEST_IMM_OP( 10, sll, 0xffffc000, 0xffffffff, 14 );
        TEST_IMM_OP( 11, sll, 0x80000000, 0xffffffff, 31 );

        TEST_IMM_OP( 12, sll, 0x21212121, 0x21212121, 0  );
        TEST_IMM_OP( 13, sll, 0x42424242, 0x21212121, 1  );
        TEST_IMM_OP( 14, sll, 0x90909080, 0x21212121, 7  );
        TEST_IMM_OP( 15, sll, 0x48484000, 0x21212121, 14 );
        TEST_IMM_OP( 16, sll, 0x80000000, 0x21212121, 31 );

        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_IMM_SRC1_EQ_DEST( 17, sll, 0x00000080, 0x00000001, 7 );
        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_IMM_DEST_BYPASS( 18, 0, sll, 0x00000080, 0x00000001, 7  );
        TEST_IMM_DEST_BYPASS( 19, 1, sll, 0x00004000, 0x00000001, 14 );
        TEST_IMM_DEST_BYPASS( 20, 2, sll, 0x80000000, 0x00000001, 31 );

        TEST_IMM_SRC1_BYPASS( 21, 0, sll, 0x00000080, 0x00000001, 7  );
        TEST_IMM_SRC1_BYPASS( 22, 1, sll, 0x00004000, 0x00000001, 14 );        
        TEST_IMM_SRC1_BYPASS( 23, 2, sll, 0x80000000, 0x00000001, 31 );
        
        TEST_PASSFAIL

