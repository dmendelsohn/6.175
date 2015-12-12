#include "smipstest.h"

        .text
main:        

        addiu $8, $0, 1
1:      beq   $0, $8, 1b
2:      beq   $0, $8, 2b
3:      beq   $0, $8, 3b
4:      beq   $0, $8, 4b
5:      beq   $0, $8, 5b
6:      beq   $0, $8, 6b
        addiu $2, $0, 1
7:      beq   $0, $2, 7b
        addiu $3, $0, 1
8:      beq   $0, $3, 8b
        mtc0  $0, $21
9:      beq   $0, $0, 9b

