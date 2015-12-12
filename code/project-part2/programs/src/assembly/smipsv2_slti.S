#*****************************************************************************
# smipsv2_slti.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_slti.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test slti instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------
         
        TEST_IMM_OP( 2,  slti, 0, 0x00000000, 0x0000 );
        TEST_IMM_OP( 3,  slti, 0, 0x00000001, 0x0001 );
        TEST_IMM_OP( 4,  slti, 1, 0x00000003, 0x0007 );
        TEST_IMM_OP( 5,  slti, 0, 0x00000007, 0x0003 );        
                                                                    
        TEST_IMM_OP( 6,  slti, 0, 0x00000000, 0x8000 );
        TEST_IMM_OP( 7,  slti, 1, 0x80000000, 0x0000 );
        TEST_IMM_OP( 8,  slti, 1, 0x80000000, 0x8000 );
        
        TEST_IMM_OP( 9,  slti, 1, 0x00000000, 0x7fff );
        TEST_IMM_OP( 10, slti, 0, 0x7fffffff, 0x0000 );
        TEST_IMM_OP( 11, slti, 0, 0x7fffffff, 0x7fff );
                                                                            
        TEST_IMM_OP( 12, slti, 1, 0x80000000, 0x7fff );
        TEST_IMM_OP( 13, slti, 0, 0x7fffffff, 0x8000 );

        TEST_IMM_OP( 14, slti, 0, 0x00000000, 0xffff );
        TEST_IMM_OP( 15, slti, 1, 0xffffffff, 0x0001 );
        TEST_IMM_OP( 16, slti, 0, 0xffffffff, 0xffff );
        
        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_IMM_SRC1_EQ_DEST( 17, sltiu, 1, 11, 13 );
                        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_IMM_DEST_BYPASS( 18, 0, slti, 0, 15, 10 );
        TEST_IMM_DEST_BYPASS( 19, 1, slti, 1, 10, 16 );
        TEST_IMM_DEST_BYPASS( 20, 2, slti, 0, 16,  9 );
        
        TEST_IMM_SRC1_BYPASS( 21, 0, slti, 1, 11, 15 );
        TEST_IMM_SRC1_BYPASS( 22, 1, slti, 0, 17,  8 );
        TEST_IMM_SRC1_BYPASS( 23, 2, slti, 1, 12, 14 );
        
        TEST_PASSFAIL

