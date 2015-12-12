#*****************************************************************************
# smipsv2_addu.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_addu.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test addu instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------
         
        TEST_RR_OP( 2,  addu, 0x00000000, 0x00000000, 0x00000000 );
        TEST_RR_OP( 3,  addu, 0x00000002, 0x00000001, 0x00000001 );
        TEST_RR_OP( 4,  addu, 0x0000000a, 0x00000003, 0x00000007 );
                                                                              
        TEST_RR_OP( 5,  addu, 0xffff8000, 0x00000000, 0xffff8000 );
        TEST_RR_OP( 6,  addu, 0x80000000, 0x80000000, 0x00000000 );
        TEST_RR_OP( 7,  addu, 0x7fff8000, 0x80000000, 0xffff8000 );
        
        TEST_RR_OP( 8,  addu, 0x00007fff, 0x00000000, 0x00007fff );
        TEST_RR_OP( 9,  addu, 0x7fffffff, 0x7fffffff, 0x00000000 );
        TEST_RR_OP( 10, addu, 0x80007ffe, 0x7fffffff, 0x00007fff );
                                                                                      
        TEST_RR_OP( 11, addu, 0x80007fff, 0x80000000, 0x00007fff );
        TEST_RR_OP( 12, addu, 0x7fff7fff, 0x7fffffff, 0xffff8000 );
        
        TEST_RR_OP( 13, addu, 0xffffffff, 0x00000000, 0xffffffff );
        TEST_RR_OP( 14, addu, 0x00000000, 0xffffffff, 0x00000001 );
        TEST_RR_OP( 15, addu, 0xfffffffe, 0xffffffff, 0xffffffff );

        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_RR_SRC1_EQ_DEST( 16, addu, 24, 13, 11 );
        TEST_RR_SRC2_EQ_DEST( 17, addu, 25, 14, 11 );
        TEST_RR_SRC12_EQ_DEST( 18, addu, 26, 13 );
        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_RR_DEST_BYPASS( 19, 0, addu, 24, 13, 11 );
        TEST_RR_DEST_BYPASS( 20, 1, addu, 25, 14, 11 );
        TEST_RR_DEST_BYPASS( 21, 2, addu, 26, 15, 11 );

        TEST_RR_SRC12_BYPASS( 22, 0, 0, addu, 24, 13, 11 );
        TEST_RR_SRC12_BYPASS( 23, 0, 1, addu, 25, 14, 11 );        
        TEST_RR_SRC12_BYPASS( 24, 0, 2, addu, 26, 15, 11 );
        TEST_RR_SRC12_BYPASS( 25, 1, 0, addu, 24, 13, 11 );
        TEST_RR_SRC12_BYPASS( 26, 1, 1, addu, 25, 14, 11 );        
        TEST_RR_SRC12_BYPASS( 27, 2, 0, addu, 26, 15, 11 );

        TEST_RR_SRC21_BYPASS( 28, 0, 0, addu, 24, 13, 11 );
        TEST_RR_SRC21_BYPASS( 29, 0, 1, addu, 25, 14, 11 );        
        TEST_RR_SRC21_BYPASS( 30, 0, 2, addu, 26, 15, 11 );
        TEST_RR_SRC21_BYPASS( 31, 1, 0, addu, 24, 13, 11 );
        TEST_RR_SRC21_BYPASS( 32, 1, 1, addu, 25, 14, 11 );        
        TEST_RR_SRC21_BYPASS( 33, 2, 0, addu, 26, 15, 11 );

        TEST_PASSFAIL

