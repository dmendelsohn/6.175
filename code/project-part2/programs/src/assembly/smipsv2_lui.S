#*****************************************************************************
# smipsv2_lui.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_lui.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test lui instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Basic tests
        #-------------------------------------------------------------

        TEST_CASE( 2, $2, 0x00000000, lui $2, 0x0000 );
        TEST_CASE( 3, $2, 0xffff0000, lui $2, 0xffff );
        TEST_CASE( 4, $2, 0x7fff0000, lui $2, 0x7fff ); 
        TEST_CASE( 5, $2, 0x80000000, lui $2, 0x8000 );

        TEST_PASSFAIL

