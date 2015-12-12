#*****************************************************************************
# smipsv3_sc.S
#-----------------------------------------------------------------------------
# Test sc instruction.
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:        
        // $2 = coreid
        mfc0  $2, $15
        bne   $2, $0, pass

        # Test 1: Store then load some data

        # Initialization:
        #   $2 = memory address
        #   $3 = initial data
        #   $4 = SC data
        #   $5 = temp register
        #   $6 = 1
        #   $8 = return register
        addiu $2, $0, %lo(tdat)
        addiu $3, $0, 0xcafe
        addiu $4, $0, 0xbeef
        addiu $5, $0, 0x0001
        addiu $6, $0, 0x0001
        sw    $3, 0($2)

        # Try to do a conditional store without a previous load link
        # This should fail
        addiu $5, $4, 0
        sc    $5, 0($2)
        addiu $8, $0, 1
        bne   $5, $0, fail
        
        # Now make sure sc did not change the memory
        lw    $5, 0($2)
        addiu $8, $0, 2
        bne   $5, $3, fail

        # Now make sure the standard lw instruction did not make a link
        # This should fail again
        addiu $5, $4, 0
        sc    $5, 0($2)
        addiu $8, $0, 3
        bne   $5, $0, fail

        # Again, make sure sc did not change the memory
        lw    $5, 0($2)
        addiu $8, $0, 4
        bne   $5, $3, fail

        # Now lets do a load link
        # This test will make sure ll got the right data
        addiu $5, $0, 0
        ll    $5, 0($2)
        addiu $8, $0, 5
        bne   $5, $3, fail

        # Now lets try to break the link with only a single thread.
        # With two threads, a write from the second thread could force
        # the line containing $2 to be evicted breaking the link.
        # With only one thread, we will do a lot of reads that should alias
        # to the same cache index in order to evict the desired line.
        lw    $5, 0x1000($2)
        lw    $5, 0x2000($2)
        lw    $5, 0x3000($2)
        lw    $5, 0x4000($2)
        lw    $5, 0x5000($2)
        lw    $5, 0x6000($2)
        lw    $5, 0x7000($2)
        lw    $5, 0x8000($2)
        lw    $5, 0x9000($2)
        lw    $5, 0xa000($2)
        lw    $5, 0xb000($2)
        lw    $5, 0xc000($2)
        lw    $5, 0xd000($2)
        lw    $5, 0xe000($2)
        lw    $5, 0xf000($2)

        # Now make sure the link was broken when the line containing $2 was
        # evicted from the cache.
        addiu $5, $4, 0
        sc    $5, 0($2)
        addiu $8, $0, 6
        bne   $5, $0, fail

        # Now lets do ll followed by sc
        addiu $5, $0, 0
        ll    $5, 0($2)
        addiu $8, $0, 7
        bne   $5, $3, fail

        addiu $5, $4, 0
        sc    $5, 0($2)
        addiu $8, $0, 8
        bne   $5, $6, fail

        # Make sure the write actually happened
        lw    $5, 0($2)
        addiu $8, $0, 9
        bne   $5, $4, fail

        # If we made it here, all the tests were successful
        beq   $0, $0, pass
        
        addiu $8, $0, 10
fail:          
        # Return the value in register 8 to track what test failed
        mtc0  $8, $21      
1:      beq   $0, $0, 1b    

pass:      
        mtc0  $0, $21       
1:      beq   $0, $0, 1b    

        #-------------------------------------------------------------
        # Test data
        #-------------------------------------------------------------

        .data
tdat:
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
        .word 0xdeadbeef
