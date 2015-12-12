#*****************************************************************************
# smipsv1_simple.S
#-----------------------------------------------------------------------------
# $Id: smipsv1_simple.S,v 1.1.1.1 2006/02/20 03:53:12 cbatten Exp $
#
# This is the most basic self checking test. If your simulator does not
# pass thiss then there is little chance that it will pass any of the      
# more complicated self checking tests.
#       

#include "smipstest.h"
        
TEST_SMIPSRAW

        .text
main:        
        
        # Set the tohost register to one indicating a passed test

        mtc0 $0, $21
1:	beq $0, $0, 1b

        # Insert some nops so that test harness has time to stop 
        # the simulation after it sees a one in tohost 

        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        

