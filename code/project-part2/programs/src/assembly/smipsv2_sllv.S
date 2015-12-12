#*****************************************************************************
# smipsv2_sllv.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_sllv.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test sllv instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------

        TEST_RR_OP( 2,  sllv, 0x00000001, 0x00000001, 0  );
        TEST_RR_OP( 3,  sllv, 0x00000002, 0x00000001, 1  );
        TEST_RR_OP( 4,  sllv, 0x00000080, 0x00000001, 7  );        
        TEST_RR_OP( 5,  sllv, 0x00004000, 0x00000001, 14 );
        TEST_RR_OP( 6,  sllv, 0x80000000, 0x00000001, 31 );

        TEST_RR_OP( 7,  sllv, 0xffffffff, 0xffffffff, 0  );
        TEST_RR_OP( 8,  sllv, 0xfffffffe, 0xffffffff, 1  );
        TEST_RR_OP( 9,  sllv, 0xffffff80, 0xffffffff, 7  );
        TEST_RR_OP( 10, sllv, 0xffffc000, 0xffffffff, 14 );
        TEST_RR_OP( 11, sllv, 0x80000000, 0xffffffff, 31 );

        TEST_RR_OP( 12, sllv, 0x21212121, 0x21212121, 0  );
        TEST_RR_OP( 13, sllv, 0x42424242, 0x21212121, 1  );
        TEST_RR_OP( 14, sllv, 0x90909080, 0x21212121, 7  );
        TEST_RR_OP( 15, sllv, 0x48484000, 0x21212121, 14 );
        TEST_RR_OP( 16, sllv, 0x80000000, 0x21212121, 31 );

        # Verify that shifts only use bottom five bits

        TEST_RR_OP( 17, sllv, 0x21212121, 0x21212121, 0xffffffe0 );
        TEST_RR_OP( 18, sllv, 0x42424242, 0x21212121, 0xffffffe1 );
        TEST_RR_OP( 19, sllv, 0x90909080, 0x21212121, 0xffffffe7 );
        TEST_RR_OP( 20, sllv, 0x48484000, 0x21212121, 0xffffffee );
        TEST_RR_OP( 21, sllv, 0x80000000, 0x21212121, 0xffffffff );        
                                 
        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_RR_SRC1_EQ_DEST( 22, sllv, 0x00000080, 0x00000001, 7  );
        TEST_RR_SRC2_EQ_DEST( 23, sllv, 0x00004000, 0x00000001, 14 );
        TEST_RR_SRC12_EQ_DEST( 24, sllv, 24, 3 );
        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_RR_DEST_BYPASS( 25, 0, sllv, 0x00000080, 0x00000001, 7  );
        TEST_RR_DEST_BYPASS( 26, 1, sllv, 0x00004000, 0x00000001, 14 );
        TEST_RR_DEST_BYPASS( 27, 2, sllv, 0x80000000, 0x00000001, 31 );

        TEST_RR_SRC12_BYPASS( 28, 0, 0, sllv, 0x00000080, 0x00000001, 7  );
        TEST_RR_SRC12_BYPASS( 29, 0, 1, sllv, 0x00004000, 0x00000001, 14 );        
        TEST_RR_SRC12_BYPASS( 30, 0, 2, sllv, 0x80000000, 0x00000001, 31 );
        TEST_RR_SRC12_BYPASS( 31, 1, 0, sllv, 0x00000080, 0x00000001, 7  );
        TEST_RR_SRC12_BYPASS( 32, 1, 1, sllv, 0x00004000, 0x00000001, 14 );        
        TEST_RR_SRC12_BYPASS( 33, 2, 0, sllv, 0x80000000, 0x00000001, 31 );

        TEST_RR_SRC21_BYPASS( 34, 0, 0, sllv, 0x00000080, 0x00000001, 7  );
        TEST_RR_SRC21_BYPASS( 35, 0, 1, sllv, 0x00004000, 0x00000001, 14 );        
        TEST_RR_SRC21_BYPASS( 36, 0, 2, sllv, 0x80000000, 0x00000001, 31 );
        TEST_RR_SRC21_BYPASS( 37, 1, 0, sllv, 0x00000080, 0x00000001, 7  );
        TEST_RR_SRC21_BYPASS( 38, 1, 1, sllv, 0x00004000, 0x00000001, 14 );        
        TEST_RR_SRC21_BYPASS( 39, 2, 0, sllv, 0x80000000, 0x00000001, 31 );
        
        TEST_PASSFAIL

