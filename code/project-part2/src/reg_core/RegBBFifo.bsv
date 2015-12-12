// branch bits fifos
//   A set of fifos for killing instructions based on branch bits and clearing
//   branch bits in place.

import Vector::*;
import TypeClasses::*;
import ProcTypes::*;
import BBFifo::*;

// uses interface from BBFifo.bsv

// Conflicting BB FIFO
module mkRegBBFifo( BBFifo#(n, t) ) provisos (Bits#(t,tSz), HasBranchBits#(t));
    // storage elements
    Vector#(n, Reg#(t))     data    <- replicateM(mkRegU);
    Vector#(n, Reg#(Bool))  valid   <- replicateM(mkReg(False));
    Reg#(Bit#(TLog#(n)))    enqP    <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP    <- mkReg(0);

    // useful value
    Bit#(TLog#(n))      max_index   = fromInteger(valueOf(n)-1);

    // some combinational logic
    Bool can_deq = valid[deqP];
    Bool can_enq = !valid[enqP];

    Bool notEmpty = readVReg(valid) != replicate(False);

    rule doRemoveBubble( !valid[deqP] && (deqP != enqP || notEmpty) );
        // move the deq pointer anyway to remove invalid bubbles
        deqP <= (deqP == max_index) ? 0 : deqP + 1;
    endrule

    method Bool canEnq = can_enq;

    method Action enq(t x) if( can_enq );
        data[enqP] <= x;
        valid[enqP] <= True;
        enqP <= (enqP == max_index) ? 0 : enqP + 1;
    endmethod

    method Bool canDeq = can_deq;

    method Action deq if( can_deq );
        valid[deqP] <= False;
        deqP <= (deqP == max_index) ? 0 : deqP + 1;
    endmethod

    method t first if( can_deq );
        return data[ deqP ];
    endmethod

    method Action clear;
        writeVReg(valid, replicate(False));
    endmethod

    method Action badBranch( CheckpointTag x );
        for( Integer i = 0 ; i < valueOf(n) ; i = i + 1 ) begin
            if( getBranchBit(data[i], x) ) begin
                valid[i] <= False;
            end
        end
    endmethod

    method Action goodBranch( CheckpointTag x );
        for( Integer i = 0 ; i < valueOf(n) ; i = i + 1 ) begin
            data[i] <= clearBranchBit( data[i], x );
        end
    endmethod
endmodule

