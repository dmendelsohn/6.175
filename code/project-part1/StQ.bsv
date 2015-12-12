import Vector::*;

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import CacheTypes::*;
import NBCacheTypes::*;

typedef struct {
    Addr            addr;
    Data            data;
    MemOp           op;     // st or sc
    NBCacheToken    token;  // only for sc
} StQData deriving(Bits, Eq, FShow);

interface StQ#(numeric type size);
    method Maybe#(Data) search(Addr x);
    method Action enq(StQData x);
    method Bool empty;
    method Action deq;
    method StQData first;
endinterface

module mkStQ(StQ#(n));
    Vector#(n, Reg#(StQData)) data <- replicateM(mkReg(?));
    Reg#(Bit#(TLog#(n))) enqP <- mkReg(0);
    Reg#(Bit#(TLog#(n))) deqP <- mkReg(0);
    Reg#(Bool) empty_reg <- mkReg(True);
    Reg#(Bool) full_reg <-mkReg(False);

    Bit#(TLog#(n)) max_index = fromInteger(valueOf(n) - 1);

    method Maybe#(Data) search(Addr x);
        Maybe#(Data) ret = tagged Invalid;
        Bool deqP_lt_enqP = deqP < enqP;
        // Get the youngest matching request
        for( Integer i = 0 ; i < valueOf(n) ; i = i+1 ) begin
            if( fromInteger(i) >= deqP ) begin
                if( deqP_lt_enqP ) begin
                    if( fromInteger(i) < enqP ) begin
                        // valid
                        if( x == data[i].addr ) begin
                            ret = tagged Valid data[i].data;
                        end
                    end
                end else if( !empty_reg ) begin
                    // valid
                    if( x == data[i].addr ) begin
                        ret = tagged Valid data[i].data;
                    end
                end
            end
        end
        for( Integer i = 0 ; i < valueOf(n) ; i = i+1 ) begin
            if( fromInteger(i) < enqP ) begin
                if( !deqP_lt_enqP && !empty_reg ) begin
                    // valid
                    if( x == data[i].addr ) begin
                        ret = tagged Valid data[i].data;
                    end
                end
            end
        end
        return ret;
    endmethod

    method Action enq(StQData x) if( !full_reg );
        data[enqP] <= x;
        let enqP_next = (enqP == max_index) ? 0 : enqP+1;
        enqP <= enqP_next;
        empty_reg <= False;
        if( enqP_next == deqP ) begin
            full_reg <= True;
        end
    endmethod

    method Bool empty = empty_reg;

    method Action deq if( !empty_reg );
        let deqP_next = (deqP == max_index) ? 0 : deqP+1;
        deqP <= deqP_next;
        full_reg <= False;
        if( deqP_next == enqP ) begin
            empty_reg <= True;
        end
    endmethod

    method StQData first if( !empty_reg );
        return data[deqP];
    endmethod
endmodule
