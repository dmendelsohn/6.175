import Vector::*;

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import CacheTypes::*;
import NBCacheTypes::*;

typedef struct {
    Addr            addr;
    MemOp           op;     // ld or ll
    NBCacheToken    token;  // corresponds to size of ooo_buffer
} LdBuffData deriving(Bits, Eq, FShow);

interface LdBuff#(numeric type size);
    method Maybe#(Tuple2#(Bit#(TLog#(size)), LdBuffData)) searchHit(Addr x);
    method Maybe#(LdBuffData) searchConflict(Addr x);
    method Action remove(Bit#(TLog#(size)) x);
    method Action enq(LdBuffData x);
endinterface

module mkLdBuff(LdBuff#(n));
    Vector#(n, Reg#(LdBuffData)) data <- replicateM(mkReg(?));
    Vector#(n, Reg#(Bool)) valid <- replicateM(mkReg(False));
    Reg#(Bit#(TLog#(n))) enqP <- mkReg(0);

    Bit#(TLog#(n)) max_index = fromInteger(valueOf(n) - 1);

    method Maybe#(Tuple2#(Bit#(TLog#(n)), LdBuffData)) searchHit(Addr x);
        Maybe#(Tuple2#(Bit#(TLog#(n)), LdBuffData)) ret = tagged Invalid;
        // Get the oldest matching request
        let targetIndex = getIndex(x);
        let targetTag = getTag(x);
        for( Integer i = valueOf(n)-1 ; i >= 0 ; i = i-1 ) begin
            if( valid[i] && (fromInteger(i) < enqP) ) begin
                if( targetIndex == getIndex(data[i].addr) && targetTag == getTag(data[i].addr) ) begin
                    ret = tagged Valid tuple2(fromInteger(i), data[i]);
                end
            end
        end
        for( Integer i = valueOf(n)-1 ; i >= 0 ; i = i-1 ) begin
            if( valid[i] && (fromInteger(i) >= enqP) ) begin
                // valid
                if( targetIndex == getIndex(data[i].addr) && targetTag == getTag(data[i].addr) ) begin
                    ret = tagged Valid tuple2(fromInteger(i), data[i]);
                end
            end
        end
        return ret;
    endmethod

    method Maybe#(LdBuffData) searchConflict(Addr x);
        Maybe#(LdBuffData) ret = tagged Invalid;
        // Get the oldest matching request
        let targetIndex = getIndex(x);
        let targetTag = getTag(x);
        for( Integer i = valueOf(n)-1 ; i >= 0 ; i = i-1 ) begin
            if( valid[i] && (fromInteger(i) < enqP) ) begin
                if( targetIndex == getIndex(data[i].addr) && targetTag != getTag(data[i].addr) ) begin
                    // same index, different tag
                    ret = tagged Valid data[i];
                end
            end
        end
        for( Integer i = valueOf(n)-1 ; i >= 0 ; i = i-1 ) begin
            if( valid[i] && (fromInteger(i) >= enqP) ) begin
                // valid
                if( targetIndex == getIndex(data[i].addr) && targetTag != getTag(data[i].addr) ) begin
                    // same index, different tag
                    ret = tagged Valid data[i];
                end
            end
        end
        return ret;
    endmethod

    method Action remove(Bit#(TLog#(n)) x);
        valid[x] <= False;
    endmethod

    method Action enq(LdBuffData x) if( !valid[enqP] );
        data[enqP] <= x;
        valid[enqP] <= True;
        enqP <= (enqP == max_index) ? 0 : enqP+1;
    endmethod
endmodule
