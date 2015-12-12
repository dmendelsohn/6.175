import Ehr::*;
import Vector::*;
import GetPut::*;
import Fifo::*;

// Uses Fifo interface from Fifo.bsv

/////////////////
// Conflict FIFO

module mkRegFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    method Bool notFull = !full;

    method Action enq(t x) if( !full );
        data[enqP] <= x;
        empty <= False;
        let next_enqP = (enqP == max_index) ? 0 : enqP + 1;
        if( next_enqP == deqP ) begin
            full <= True;
        end
        enqP <= next_enqP;
    endmethod

    method Bool notEmpty = !empty;

    method Action deq if( !empty );
        // Tell later stages a dequeue was requested
        full <= False;
        let next_deqP = (deqP == max_index) ? 0 : deqP + 1;
        if( next_deqP == enqP ) begin
            empty <= True;
        end
        deqP <= next_deqP;
    endmethod

    method t first if( !empty );
        return data[deqP];
    endmethod

    method Action clear;
        enqP <= 0;
        deqP <= 0;
        empty <= True;
        full <= False;
    endmethod
endmodule

