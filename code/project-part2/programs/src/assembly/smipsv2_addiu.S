#*****************************************************************************
# smipsv2_addiu.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_addiu.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test addiu instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------
         
        TEST_IMM_OP( 2,  addiu, 0x00000000, 0x00000000, 0x0000 );
        TEST_IMM_OP( 3,  addiu, 0x00000002, 0x00000001, 0x0001 );
        TEST_IMM_OP( 4,  addiu, 0x0000000a, 0x00000003, 0x0007 );
                                                                              
        TEST_IMM_OP( 5,  addiu, 0xffff8000, 0x00000000, 0x8000 );
        TEST_IMM_OP( 6,  addiu, 0x80000000, 0x80000000, 0x0000 );
        TEST_IMM_OP( 7,  addiu, 0x7fff8000, 0x80000000, 0x8000 );
        
        TEST_IMM_OP( 8,  addiu, 0x00007fff, 0x00000000, 0x7fff );
        TEST_IMM_OP( 9,  addiu, 0x7fffffff, 0x7fffffff, 0x0000 );
        TEST_IMM_OP( 10, addiu, 0x80007ffe, 0x7fffffff, 0x7fff );
                                                                                      
        TEST_IMM_OP( 11, addiu, 0x80007fff, 0x80000000, 0x7fff );
        TEST_IMM_OP( 12, addiu, 0x7fff7fff, 0x7fffffff, 0x8000 );
        
        TEST_IMM_OP( 13, addiu, 0xffffffff, 0x00000000, 0xffff );
        TEST_IMM_OP( 14, addiu, 0x00000000, 0xffffffff, 0x0001 );
        TEST_IMM_OP( 15, addiu, 0xfffffffe, 0xffffffff, 0xffff );

        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_IMM_SRC1_EQ_DEST( 16, addiu, 24, 13, 11 );
                        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_IMM_DEST_BYPASS( 17, 0, addiu, 24, 13, 11 );
        TEST_IMM_DEST_BYPASS( 18, 1, addiu, 23, 13, 10 );
        TEST_IMM_DEST_BYPASS( 19, 2, addiu, 22, 13,  9 );

        TEST_IMM_SRC1_BYPASS( 20, 0, addiu, 24, 13, 11 );
        TEST_IMM_SRC1_BYPASS( 21, 1, addiu, 23, 13, 10 );        
        TEST_IMM_SRC1_BYPASS( 22, 2, addiu, 22, 13,  9 );
                        
        TEST_PASSFAIL

