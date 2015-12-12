.globl __start
__start:
        // $v0 = 1
        li $2, 1
        // $v0 = main
        jal main
        // stop with status $v0
        mtc0 $2, $21
end:    j end
