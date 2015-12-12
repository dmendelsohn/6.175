#include "smipstest.h"

        .text
main:        

        # Test 1: 1 + 1 = 2
        addiu $8, $0, 1
        addu  $2, $8, $8

        mtc0  $2, $18

        mtc0  $0, $21      
1:      beq   $0, $0, 1b    

