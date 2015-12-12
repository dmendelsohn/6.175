#*****************************************************************************
# smipsv2_srav.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_srav.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test srav instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------

        TEST_RR_OP( 2,  srav, 0x80000000, 0x80000000, 0  );
        TEST_RR_OP( 3,  srav, 0xc0000000, 0x80000000, 1  );
        TEST_RR_OP( 4,  srav, 0xff000000, 0x80000000, 7  );        
        TEST_RR_OP( 5,  srav, 0xfffe0000, 0x80000000, 14 );
        TEST_RR_OP( 6,  srav, 0xffffffff, 0x80000001, 31 );

        TEST_RR_OP( 7,  srav, 0x7fffffff, 0x7fffffff, 0  );
        TEST_RR_OP( 8,  srav, 0x3fffffff, 0x7fffffff, 1  );
        TEST_RR_OP( 9,  srav, 0x00ffffff, 0x7fffffff, 7  );
        TEST_RR_OP( 10, srav, 0x0001ffff, 0x7fffffff, 14 );
        TEST_RR_OP( 11, srav, 0x00000000, 0x7fffffff, 31 );

        TEST_RR_OP( 12, srav, 0x81818181, 0x81818181, 0  );
        TEST_RR_OP( 13, srav, 0xc0c0c0c0, 0x81818181, 1  );
        TEST_RR_OP( 14, srav, 0xff030303, 0x81818181, 7  );
        TEST_RR_OP( 15, srav, 0xfffe0606, 0x81818181, 14 );
        TEST_RR_OP( 16, srav, 0xffffffff, 0x81818181, 31 );

        # Verify that shifts only use bottom five bits

        TEST_RR_OP( 17, srav, 0x81818181, 0x81818181, 0xffffffe0 );
        TEST_RR_OP( 18, srav, 0xc0c0c0c0, 0x81818181, 0xffffffe1 );
        TEST_RR_OP( 19, srav, 0xff030303, 0x81818181, 0xffffffe7 );
        TEST_RR_OP( 20, srav, 0xfffe0606, 0x81818181, 0xffffffee );
        TEST_RR_OP( 21, srav, 0xffffffff, 0x81818181, 0xffffffff );        
                                 
        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_RR_SRC1_EQ_DEST( 22, srav, 0xff000000, 0x80000000, 7  );
        TEST_RR_SRC2_EQ_DEST( 23, srav, 0xfffe0000, 0x80000000, 14 );
        TEST_RR_SRC12_EQ_DEST( 24, srav, 0, 7 );
        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_RR_DEST_BYPASS( 25, 0, srav, 0xff000000, 0x80000000, 7  );
        TEST_RR_DEST_BYPASS( 26, 1, srav, 0xfffe0000, 0x80000000, 14 );
        TEST_RR_DEST_BYPASS( 27, 2, srav, 0xffffffff, 0x80000000, 31 );

        TEST_RR_SRC12_BYPASS( 28, 0, 0, srav, 0xff000000, 0x80000000, 7  );
        TEST_RR_SRC12_BYPASS( 29, 0, 1, srav, 0xfffe0000, 0x80000000, 14 );        
        TEST_RR_SRC12_BYPASS( 30, 0, 2, srav, 0xffffffff, 0x80000000, 31 );
        TEST_RR_SRC12_BYPASS( 31, 1, 0, srav, 0xff000000, 0x80000000, 7  );
        TEST_RR_SRC12_BYPASS( 32, 1, 1, srav, 0xfffe0000, 0x80000000, 14 );        
        TEST_RR_SRC12_BYPASS( 33, 2, 0, srav, 0xffffffff, 0x80000000, 31 );

        TEST_RR_SRC21_BYPASS( 34, 0, 0, srav, 0xff000000, 0x80000000, 7  );
        TEST_RR_SRC21_BYPASS( 35, 0, 1, srav, 0xfffe0000, 0x80000000, 14 );        
        TEST_RR_SRC21_BYPASS( 36, 0, 2, srav, 0xffffffff, 0x80000000, 31 );
        TEST_RR_SRC21_BYPASS( 37, 1, 0, srav, 0xff000000, 0x80000000, 7  );
        TEST_RR_SRC21_BYPASS( 38, 1, 1, srav, 0xfffe0000, 0x80000000, 14 );        
        TEST_RR_SRC21_BYPASS( 39, 2, 0, srav, 0xffffffff, 0x80000000, 31 );
        
        TEST_PASSFAIL

