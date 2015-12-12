.globl __mc_start
__mc_start:
        // $a0 = coreID
        mfc0 $4, $15
        // $8 = $a0 << 16
        sll $8, $4, 16
        // $sp = - $8
        subu $29, $0, $8
        // $v0 = 1
        li $2, 1
        // $v0 = main($a0)
        jal main
        // stop with status $v0
        mtc0 $2, $21
end:    j end
