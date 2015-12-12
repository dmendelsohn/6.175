#*****************************************************************************
# smipsv2_sra.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_sra.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test sra instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Arithmetic tests
        #-------------------------------------------------------------

        TEST_IMM_OP( 2,  sra, 0x80000000, 0x80000000, 0  );
        TEST_IMM_OP( 3,  sra, 0xc0000000, 0x80000000, 1  );
        TEST_IMM_OP( 4,  sra, 0xff000000, 0x80000000, 7  );        
        TEST_IMM_OP( 5,  sra, 0xfffe0000, 0x80000000, 14 );
        TEST_IMM_OP( 6,  sra, 0xffffffff, 0x80000001, 31 );

        TEST_IMM_OP( 7,  sra, 0x7fffffff, 0x7fffffff, 0  );
        TEST_IMM_OP( 8,  sra, 0x3fffffff, 0x7fffffff, 1  );
        TEST_IMM_OP( 9,  sra, 0x00ffffff, 0x7fffffff, 7  );
        TEST_IMM_OP( 10, sra, 0x0001ffff, 0x7fffffff, 14 );
        TEST_IMM_OP( 11, sra, 0x00000000, 0x7fffffff, 31 );

        TEST_IMM_OP( 12, sra, 0x81818181, 0x81818181, 0  );
        TEST_IMM_OP( 13, sra, 0xc0c0c0c0, 0x81818181, 1  );
        TEST_IMM_OP( 14, sra, 0xff030303, 0x81818181, 7  );
        TEST_IMM_OP( 15, sra, 0xfffe0606, 0x81818181, 14 );
        TEST_IMM_OP( 16, sra, 0xffffffff, 0x81818181, 31 );

        #-------------------------------------------------------------
        # Source/Destination tests
        #-------------------------------------------------------------

        TEST_IMM_SRC1_EQ_DEST( 17, sra, 0xff000000, 0x80000000, 7 );
        
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_IMM_DEST_BYPASS( 18, 0, sra, 0xff000000, 0x80000000, 7  );
        TEST_IMM_DEST_BYPASS( 19, 1, sra, 0xfffe0000, 0x80000000, 14 );
        TEST_IMM_DEST_BYPASS( 20, 2, sra, 0xffffffff, 0x80000001, 31 );

        TEST_IMM_SRC1_BYPASS( 21, 0, sra, 0xff000000, 0x80000000, 7 );
        TEST_IMM_SRC1_BYPASS( 22, 1, sra, 0xfffe0000, 0x80000000, 14 );        
        TEST_IMM_SRC1_BYPASS( 23, 2, sra, 0xffffffff, 0x80000001, 31 );
        
        TEST_PASSFAIL

