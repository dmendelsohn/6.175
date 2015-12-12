#*****************************************************************************
# smipsv2_lw.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_lw.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test lw instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Basic tests
        #-------------------------------------------------------------

        TEST_LD_OP( 2, lw, 0x00ff00ff, 0,  tdat );
        TEST_LD_OP( 3, lw, 0xff00ff00, 4,  tdat );
        TEST_LD_OP( 4, lw, 0x0ff00ff0, 8,  tdat );
        TEST_LD_OP( 5, lw, 0xf00ff00f, 12, tdat );

        # Test with negative offset
        
        TEST_LD_OP( 6, lw, 0x00ff00ff, -12, tdat4 );
        TEST_LD_OP( 7, lw, 0xff00ff00, -8,  tdat4 );
        TEST_LD_OP( 8, lw, 0x0ff00ff0, -4,  tdat4 );
        TEST_LD_OP( 9, lw, 0xf00ff00f, 0,   tdat4 );
       
        # Test with a negative base

        TEST_CASE( 10, $4, 0x00ff00ff, \
          la $2, tdat; \
          addiu $2, $2, -32; \
          lw $4, 32($2); \
        )

        # Test with unaligned base

        TEST_CASE( 11, $4, 0xff00ff00, \
          la $2, tdat; \
          addiu $2, $2, -3; \
          lw $4, 7($2); \
        )

        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_LD_DEST_BYPASS( 12, 0, lw, 0x0ff00ff0, 4, tdat2 );
        TEST_LD_DEST_BYPASS( 13, 1, lw, 0xf00ff00f, 4, tdat3 );        
        TEST_LD_DEST_BYPASS( 14, 2, lw, 0xff00ff00, 4, tdat1 );

        TEST_LD_SRC1_BYPASS( 15, 0, lw, 0x0ff00ff0, 4, tdat2 );
        TEST_LD_SRC1_BYPASS( 16, 1, lw, 0xf00ff00f, 4, tdat3 );
        TEST_LD_SRC1_BYPASS( 17, 2, lw, 0xff00ff00, 4, tdat1 );
        
        #-------------------------------------------------------------
        # Test write-after-write hazard
        #-------------------------------------------------------------

        TEST_CASE( 18, $3, 2, \
          la $4, tdat; \
          lw $3, 0($4); \
          li $3, 2; \
        )

        TEST_CASE( 19, $3, 2, \
          la $4, tdat; \
          lw $3, 0($4); \
          nop; \
          li $3, 2; \
        )        
        
        TEST_PASSFAIL

        
        #-------------------------------------------------------------
        # Test data
        #-------------------------------------------------------------

        .data
tdat:
tdat1:  .word 0x00ff00ff
tdat2:  .word 0xff00ff00        
tdat3:  .word 0x0ff00ff0
tdat4:  .word 0xf00ff00f
                
