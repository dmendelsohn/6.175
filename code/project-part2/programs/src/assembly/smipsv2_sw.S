#*****************************************************************************
# smipsv2_sw.S
#-----------------------------------------------------------------------------
# $Id: smipsv2_sw.S,v 1.1.1.1 2006/02/20 03:53:13 cbatten Exp $
#
# Test sw instruction.
#       

#include "smipstest.h"
#include "test_macros.h"
                
TEST_SMIPSRAW

        .text
main:

        #-------------------------------------------------------------
        # Basic tests
        #-------------------------------------------------------------

        TEST_ST_OP( 2, lw, sw, 0x00aa00aa, 0,  tdat );
        TEST_ST_OP( 3, lw, sw, 0xaa00aa00, 4,  tdat );
        TEST_ST_OP( 4, lw, sw, 0x0aa00aa0, 8,  tdat );
        TEST_ST_OP( 5, lw, sw, 0xa00aa00a, 12, tdat );

        # Test with negative offset
        
        TEST_ST_OP( 6, lw, sw, 0x00aa00aa, -12, tdat8 );
        TEST_ST_OP( 7, lw, sw, 0xaa00aa00, -8,  tdat8 );
        TEST_ST_OP( 8, lw, sw, 0x0aa00aa0, -4,  tdat8 );
        TEST_ST_OP( 9, lw, sw, 0xa00aa00a, 0,   tdat8 );
       
        # Test with a negative base

        TEST_CASE( 10, $4, 0x12345678, \
          la $2, tdat9; \
          li $3, 0x12345678; \
          addiu $5, $2, -32; \
          sw $3, 32($5); \
          lw $4, 0($2); \
        )

        # Test with unaligned base

        TEST_CASE( 11, $4, 0x58213098, \
          la $2, tdat9; \
          li $3, 0x58213098; \
          addiu $2, $2, -3; \
          sw $3, 7($2); \
          la $5, tdat10; \
          lw $4, 0($5); \
        )
                
        #-------------------------------------------------------------
        # Bypassing tests
        #-------------------------------------------------------------

        TEST_ST_SRC12_BYPASS( 12, 0, 0, lw, sw, 0xaabbccdd, 0,  tdat );
        TEST_ST_SRC12_BYPASS( 13, 0, 1, lw, sw, 0xdaabbccd, 4,  tdat );
        TEST_ST_SRC12_BYPASS( 14, 0, 2, lw, sw, 0xddaabbcc, 8,  tdat );
        TEST_ST_SRC12_BYPASS( 15, 1, 0, lw, sw, 0xcddaabbc, 12, tdat );
        TEST_ST_SRC12_BYPASS( 16, 1, 1, lw, sw, 0xccddaabb, 16, tdat );
        TEST_ST_SRC12_BYPASS( 17, 2, 0, lw, sw, 0xbccddaab, 20, tdat );
        
        TEST_ST_SRC21_BYPASS( 18, 0, 0, lw, sw, 0x00112233, 0,  tdat );
        TEST_ST_SRC21_BYPASS( 19, 0, 1, lw, sw, 0x30011223, 4,  tdat );        
        TEST_ST_SRC21_BYPASS( 20, 0, 2, lw, sw, 0x33001122, 8,  tdat );
        TEST_ST_SRC21_BYPASS( 21, 1, 0, lw, sw, 0x23300112, 12, tdat );
        TEST_ST_SRC21_BYPASS( 22, 1, 1, lw, sw, 0x22330011, 16, tdat );
        TEST_ST_SRC21_BYPASS( 23, 2, 0, lw, sw, 0x12233001, 20, tdat );

        TEST_PASSFAIL


        #-------------------------------------------------------------
        # Test data
        #-------------------------------------------------------------

        .data
tdat:
tdat1:  .word 0xdeadbeef
tdat2:  .word 0xdeadbeef        
tdat3:  .word 0xdeadbeef
tdat4:  .word 0xdeadbeef
tdat5:  .word 0xdeadbeef
tdat6:  .word 0xdeadbeef        
tdat7:  .word 0xdeadbeef
tdat8:  .word 0xdeadbeef        
tdat9:  .word 0xdeadbeef         
tdat10: .word 0xdeadbeef

        