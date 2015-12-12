import Vector::*;
import RegFile::*;
import Fifo::*;
import RegFifo::*;
import ProcTypes::*;

function CacheOffset getOffset(Addr addr);
    return truncate(addr >> 2);
endfunction

function CacheIndex getIndex(Addr addr);
    return truncate(addr >> (2 + valueOf(TLog#(CacheLineWords))));
endfunction

function CacheTag getTag(Addr addr);
    return truncateLSB(addr);
endfunction

// interfaces
interface NBICacheFull;
    // processor interface
    method Action req(Addr pc);
    method ActionValue#(Data) resp;
    // method void drainResp; // This is hard to integrate at the moment
    // memory interface
    method ActionValue#(Addr) memReq;
    method Action memResp(Tuple2#(Addr, CacheLine) r);
endinterface

function NBICache toNBICache( NBICacheFull mem );
    return (interface NBICache;
                method Action req(Addr r) = mem.req(r);
                method ActionValue#(Data) resp = mem.resp;
                // method void drainResp = mem.drainResp;
            endinterface);
endfunction

interface ILdBuff#(numeric type size);
    method ActionValue#(Bool) searchHit(Addr x, CacheLine d);
    method Maybe#(Addr) searchConflict(Addr x);
    method ActionValue#(Data) getValidResponse;
    method Action drainResponse;
    method Action enq(Addr x, Maybe#(Data) d);
    method Bool empty;
endinterface

module mkRegILdBuff(ILdBuff#(n));
    Vector#(n, Reg#(Addr)) addr <- replicateM(mkReg(0));
    Vector#(n, Reg#(Data)) data <- replicateM(mkReg(0));
    // Waiting should only be true for valid entries
    Vector#(n, Reg#(Bool)) waiting <- replicateM(mkReg(False));
    Reg#(Bit#(TLog#(n))) enqP <- mkReg(0);
    Reg#(Bit#(TLog#(n))) deqP <- mkReg(0);
    Reg#(Bool) notFull_reg <- mkReg(True);
    Reg#(Bool) notEmpty_reg <- mkReg(False);

    Bit#(TLog#(n)) max_index = fromInteger(valueOf(n) - 1);

    method ActionValue#(Bool) searchHit(Addr x, CacheLine d);
        // Get the oldest matching request
        let targetIndex = getIndex(x);
        let targetTag = getTag(x);

        Maybe#(Bit#(TLog#(n))) iLdBufferIndex = tagged Invalid;

        for( Integer i = valueOf(n)-1 ; i >= 0 ; i = i-1 ) begin
            if( waiting[i] && (fromInteger(i) < enqP) ) begin
                if( targetIndex == getIndex(addr[i]) && targetTag == getTag(addr[i]) ) begin
                    iLdBufferIndex = tagged Valid fromInteger(i);
                end
            end
        end
        for( Integer i = valueOf(n)-1 ; i >= 0 ; i = i-1 ) begin
            if( waiting[i] && (fromInteger(i) >= enqP) ) begin
                if( targetIndex == getIndex(addr[i]) && targetTag == getTag(addr[i]) ) begin
                    iLdBufferIndex = tagged Valid fromInteger(i);
                end
            end
        end

        if( isValid(iLdBufferIndex) ) begin
            Bit#(TLog#(n)) index = fromMaybe(?, iLdBufferIndex);
            CacheOffset wordOffset = truncate(addr[index] >> 2);
            data[index] <= d[wordOffset];
            waiting[index] <= False;
            return True;
        end else begin
            return False;
        end
    endmethod

    method Maybe#(Addr) searchConflict(Addr x);
        // Get the oldest matching request
        let targetIndex = getIndex(x);
        let targetTag = getTag(x);

        Maybe#(Addr) conflictAddr = tagged Invalid;

        for( Integer i = valueOf(n)-1 ; i >= 0 ; i = i-1 ) begin
            if( waiting[i] && (fromInteger(i) < enqP) ) begin
                if( targetIndex == getIndex(addr[i]) && targetTag != getTag(addr[i]) ) begin
                    conflictAddr = tagged Valid addr[i];
                end
            end
        end
        for( Integer i = valueOf(n)-1 ; i >= 0 ; i = i-1 ) begin
            if( waiting[i] && (fromInteger(i) >= enqP) ) begin
                if( targetIndex == getIndex(addr[i]) && targetTag != getTag(addr[i]) ) begin
                    conflictAddr = tagged Valid addr[i];
                end
            end
        end

        return conflictAddr;
    endmethod

    method ActionValue#(Data) getValidResponse() if ( notEmpty_reg && waiting[deqP] == False );
        let ret = data[deqP];
        let deqP_next = (deqP == max_index) ? 0 : deqP+1;
        if( deqP_next == enqP ) begin
            notEmpty_reg <= False;
        end
        notFull_reg <= True;
        deqP <= deqP_next;
        return ret;
    endmethod

    method Action drainResponse() if ( notEmpty_reg );
        waiting[deqP] <= False;
        let deqP_next = (deqP == max_index) ? 0 : deqP+1;
        if( deqP_next == enqP ) begin
            notEmpty_reg <= False;
        end
        notFull_reg <= True;
        deqP <= deqP_next;
    endmethod

    method Action enq(Addr x, Maybe#(Data) d) if( notFull_reg );
        addr[enqP] <= x;
        if( isValid(d) ) begin
            data[enqP] <= fromMaybe(?,d);
            waiting[enqP] <= False;
        end else begin
            waiting[enqP] <= True;
        end

        // update enqP, notEmpty, and notFull
        let enqP_next = (enqP == max_index) ? 0 : enqP+1;
        if( enqP_next == deqP ) begin
            notFull_reg <= False;
        end
        notEmpty_reg <= True;
        enqP <= enqP_next;
    endmethod

    method Bool empty = !notEmpty_reg;
endmodule

typedef enum {None, LdBuffState, LdReqState} NBICacheState deriving(Bits, Eq, FShow);

// Instruction Cache
(* synthesize *)
module mkRegNBICache(NBICacheFull);
    Vector#(CacheRows, Reg#(Bool))          valid <- replicateM(mkReg(False));
    Vector#(CacheRows, Reg#(Bool))          waitb <- replicateM(mkReg(False));
    RegFile#(CacheIndex, CacheTag)       tagArray <- mkRegFileFull;
    RegFile#(CacheIndex, CacheLine)     dataArray <- mkRegFileFull;
    ILdBuff#(LdBuffSz)                    iLdBuff <- mkRegILdBuff;

    // Cache to Memory
    Fifo#(2, Addr)                        memReqQ <- mkRegFifo;
    Fifo#(2, Tuple2#(Addr,CacheLine))    memRespQ <- mkRegFifo;
    // Cache to Processor
    Fifo#(2, Data)                          respQ <- mkRegFifo;

    Reg#(Addr)                           addrResp <- mkRegU;
    Reg#(NBICacheState)                buffSearch <- mkReg(None);

    rule handleMemResp(buffSearch == None);
        match {.addr, .data} = memRespQ.first;
        memRespQ.deq;
        let idx = getIndex(addr);
        dataArray.upd(idx, data);
        // Tag should already match
        valid[idx] <= True;
        waitb[idx] <= False;
        buffSearch <= LdBuffState;
        addrResp <= addr;
    endrule

    rule clearLoad(buffSearch == LdBuffState);
        // search the buffer for loads that match response
        let idx = getIndex(addrResp);
        let hit <- iLdBuff.searchHit(addrResp, dataArray.sub(idx));
        if(!hit) begin
            buffSearch <= LdReqState;
        end
    endrule

    rule sendLoadRequest(buffSearch == LdReqState);
        // search the buffer for loads that match previous index, but not the tag
        let addr_maybe = iLdBuff.searchConflict(addrResp);
        if (isValid(addr_maybe)) begin
            // conflict found, resend memory request
            let addr = fromMaybe(?, addr_maybe);
            let idx = getIndex(addr);
            let tag = getTag(addr);
            let line = dataArray.sub(idx);
            let w = waitb[idx];
            if(w) begin
                $fwrite(stderr, "%s::sendLoadRequest : [ERROR] Trying to resend request for index that is still waiting. This should not be possible", genModuleName);
            end
            memReqQ.enq(addr);
            valid[idx] <= False;
            waitb[idx] <= True;
            tagArray.upd(idx, tag);
        end
        buffSearch <= None;
    endrule

    method Action req(Addr addr) if (buffSearch == None);
        let idx = getIndex(addr);
        let tag = getTag(addr);
        let offset = getOffset(addr);
        let line = dataArray.sub(idx);
        let v = valid[idx];
        let tagArrayValue = tagArray.sub(idx);
        // load request
        if (tag == tagArrayValue && v) begin
            // hit from data cache
            // (all hits pass through iLdBuff)
            iLdBuff.enq(addr, tagged Valid line[offset]);
        end else begin
            // miss, so enqueue into iLdBuff
            iLdBuff.enq(addr, tagged Invalid);
            if (!waitb[idx]) begin
                memReqQ.enq(addr);
                valid[idx] <= False;
                waitb[idx] <= True;
                tagArray.upd(idx, tag);
            end else begin
                // This load will have to generate a memory request later
            end
        end
    endmethod

    method ActionValue#(Data) resp;
        let x <- iLdBuff.getValidResponse;
        return x;
    endmethod

    // method Action drainResp;
    //     iLdBuff.drainResponse;
    // endmethod

    method ActionValue#(Addr) memReq;
        memReqQ.deq;
        return memReqQ.first;
    endmethod

    method Action memResp(Tuple2#(Addr, CacheLine) r);
        memRespQ.enq(r);
    endmethod
endmodule

