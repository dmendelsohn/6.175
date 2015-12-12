#*****************************************************************************
# smipsv1_sw.S
#-----------------------------------------------------------------------------
# $Id: smipsv1_sw.S,v 1.1.1.1 2006/02/20 03:53:12 cbatten Exp $
#
# Test sw instruction. Note that since SMIPSv1 does not support a lui
# instruction we must be careful when forming addresses. We cannot use the
# standard la assembler pseudo-instruction. Instead we use the %lo(addr)
# assembler directive which tells the linker to subsitute in the low order 15
# bits of the indicated label.
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:        
        
        # Test 1: Store then load some data

        addiu $2, $0, %lo(tdat)

        addiu $3, $0, 0x00ff
        sw    $3, 0($2)
        lw    $4, 0($2)
        bne   $4, $3, fail

        addiu $3, $0, 0x7f00
        sw    $3, 4($2)
        lw    $4, 4($2)
        bne   $4, $3, fail        
                
        addiu $3, $0, 0x0ff0
        sw    $3, 8($2)
        lw    $4, 8($2)
        bne   $4, $3, fail
        
        addiu $3, $0, 0x700f
        sw    $3, 12($2)
        lw    $4, 12($2)
        bne   $4, $3, fail        
        
        # Test 2: Store then load some data (negative offsets)

        addiu $2, $0, %lo(tdat8)        

        addiu $3, $0, 0x00ff
        sw    $3, -12($2)
        lw    $4, -12($2)
        bne   $4, $3, fail

        addiu $3, $0, 0x7f00
        sw    $3, -8($2)
        lw    $4, -8($2)
        bne   $4, $3, fail        
                
        addiu $3, $0, 0x0ff0
        sw    $3, -4($2)
        lw    $4, -4($2)
        bne   $4, $3, fail
        
        addiu $3, $0, 0x700f
        sw    $3, 0($2)
        lw    $4, 0($2)
        bne   $4, $3, fail        
                                        
        # If we get here then we passed

        addiu $2, $0, 1
        bne   $0, $2, pass
        
fail:          
        addiu $2, $0, 1
        mtc0  $2, $21      
1:      beq   $0, $0, 1b    

pass:      
        mtc0  $0, $21       
1:      beq   $0, $0, 1b    

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
                
                            

        

