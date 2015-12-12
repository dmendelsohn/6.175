#*****************************************************************************
# smipsv2_srlv.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_srlv.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test srlv instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------

        TEST_RR_OP( 2,  srlv, 0x80000000, 0x80000000, 0  );
        TEST_RR_OP( 3,  srlv, 0x40000000, 0x80000000, 1  );
        TEST_RR_OP( 4,  srlv, 0x01000000, 0x80000000, 7  );        
        TEST_RR_OP( 5,  srlv, 0x00020000, 0x80000000, 14 );
        TEST_RR_OP( 6,  srlv, 0x00000001, 0x80000001, 31 );

        TEST_RR_OP( 7,  srlv, 0xffffffff, 0xffffffff, 0  );
        TEST_RR_OP( 8,  srlv, 0x7fffffff, 0xffffffff, 1  );
        TEST_RR_OP( 9,  srlv, 0x01ffffff, 0xffffffff, 7  );
        TEST_RR_OP( 10, srlv, 0x0003ffff, 0xffffffff, 14 );
        TEST_RR_OP( 11, srlv, 0x00000001, 0xffffffff, 31 );

        TEST_RR_OP( 12, srlv, 0x21212121, 0x21212121, 0  );
        TEST_RR_OP( 13, srlv, 0x10909090, 0x21212121, 1  );
        TEST_RR_OP( 14, srlv, 0x00424242, 0x21212121, 7  );
        TEST_RR_OP( 15, srlv, 0x00008484, 0x21212121, 14 );
        TEST_RR_OP( 16, srlv, 0x00000000, 0x21212121, 31 );

        # Verify that shifts only use bottom five bits

        TEST_RR_OP( 17, srlv, 0x21212121, 0x21212121, 0xffffffe0 );
        TEST_RR_OP( 18, srlv, 0x10909090, 0x21212121, 0xffffffe1 );
        TEST_RR_OP( 19, srlv, 0x00424242, 0x21212121, 0xffffffe7 );
        TEST_RR_OP( 20, srlv, 0x00008484, 0x21212121, 0xffffffee );
        TEST_RR_OP( 21, srlv, 0x00000000, 0x21212121, 0xffffffff );        
                                 
        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_RR_SRC1_EQ_DEST( 22, srlv, 0x01000000, 0x80000000, 7  );
        TEST_RR_SRC2_EQ_DEST( 23, srlv, 0x00020000, 0x80000000, 14 );
        TEST_RR_SRC12_EQ_DEST( 24, srlv, 0, 7 );
        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_RR_DEST_BYPASS( 25, 0, srlv, 0x01000000, 0x80000000, 7  );
        TEST_RR_DEST_BYPASS( 26, 1, srlv, 0x00020000, 0x80000000, 14 );
        TEST_RR_DEST_BYPASS( 27, 2, srlv, 0x00000001, 0x80000000, 31 );

        TEST_RR_SRC12_BYPASS( 28, 0, 0, srlv, 0x01000000, 0x80000000, 7  );
        TEST_RR_SRC12_BYPASS( 29, 0, 1, srlv, 0x00020000, 0x80000000, 14 );        
        TEST_RR_SRC12_BYPASS( 30, 0, 2, srlv, 0x00000001, 0x80000000, 31 );
        TEST_RR_SRC12_BYPASS( 31, 1, 0, srlv, 0x01000000, 0x80000000, 7  );
        TEST_RR_SRC12_BYPASS( 32, 1, 1, srlv, 0x00020000, 0x80000000, 14 );        
        TEST_RR_SRC12_BYPASS( 33, 2, 0, srlv, 0x00000001, 0x80000000, 31 );

        TEST_RR_SRC21_BYPASS( 34, 0, 0, srlv, 0x01000000, 0x80000000, 7  );
        TEST_RR_SRC21_BYPASS( 35, 0, 1, srlv, 0x00020000, 0x80000000, 14 );        
        TEST_RR_SRC21_BYPASS( 36, 0, 2, srlv, 0x00000001, 0x80000000, 31 );
        TEST_RR_SRC21_BYPASS( 37, 1, 0, srlv, 0x01000000, 0x80000000, 7  );
        TEST_RR_SRC21_BYPASS( 38, 1, 1, srlv, 0x00020000, 0x80000000, 14 );        
        TEST_RR_SRC21_BYPASS( 39, 2, 0, srlv, 0x00000001, 0x80000000, 31 );
        
        TEST_PASSFAIL

