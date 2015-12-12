import Vector::*;
import ProcTypes::*;
// import CacheTypes::*;

interface OoOCompletionBuffer#(numeric type size);
    method ActionValue#(Bit#(TLog#(size))) insert(MemReqInst x);
    method ActionValue#(Maybe#(MemRespInst)) remove(Bit#(TLog#(size)) index, Data x);
    method Action badBranch(CheckpointTag b);
    method Action goodBranch(CheckpointTag b);
endinterface

module mkRegOoOCompletionBuffer( OoOCompletionBuffer#(size) );
    Vector#(size, Reg#(Bool)) valid <- replicateM(mkReg(False));
    Vector#(size, Reg#(Bool)) poisoned <- replicateM(mkReg(False));
    Vector#(size, Reg#(Bit#(NumCheckpoint))) brBits <- replicateM(mkRegU);
    Vector#(size, Reg#(MemReqInst)) data <- replicateM(mkRegU);

    Reg#(Bit#(TLog#(size))) enqP <- mkReg(0);

    method ActionValue#(Bit#(TLog#(size))) insert(MemReqInst x) if (!valid[enqP]);
        // write to enqP row
        valid[enqP] <= True;
        poisoned[enqP] <= False;
        brBits[enqP] <= x.brBits;
        data[enqP] <= x;
        // increment enqP
        enqP <= (enqP == fromInteger(valueOf(size)-1)) ? 0 : enqP + 1;
        return enqP;
    endmethod

    method ActionValue#(Maybe#(MemRespInst)) remove(Bit#(TLog#(size)) index, Data x);
        valid[index] <= False;
        if( poisoned[index] ) begin
            return tagged Invalid;
        end else begin
            MemReqInst req = data[index];
            MemRespInst resp = toMemRespInst(req);
            resp.data = x;
            return tagged Valid resp;
        end
    endmethod

    method Action badBranch(CheckpointTag b);
        for( Integer i = 0 ; i < valueOf(size) ; i = i+1 ) begin
            if( brBits[i][b] == 1 ) begin
                poisoned[i] <= True;
            end
        end
    endmethod

    method Action goodBranch(CheckpointTag b);
        for( Integer i = 0 ; i < valueOf(size) ; i = i+1 ) begin
            brBits[i][b] <= 0;
        end
    endmethod
endmodule
