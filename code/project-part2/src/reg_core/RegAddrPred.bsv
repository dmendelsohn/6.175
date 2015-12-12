/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

import ProcTypes::*;
import RegFile::*;
import Vector::*;

interface AddrPred;
    method Addr predPc(Addr pc);
    method Action update(Redirect rd);
endinterface

module mkPcPlus4(AddrPred);
    method Addr predPc(Addr pc) = pc + 4;

    method Action update(Redirect rd);
        noAction;
    endmethod
endmodule

// XXX Value for quick compilation
typedef 16 BtbEntries;
// typedef 64 BtbEntries;
typedef Bit#(TLog#(BtbEntries)) BtbIndex;
typedef Bit#(TSub#(TSub#(AddrSize, TLog#(BtbEntries)), 2)) BtbTag;

(* synthesize *)
module mkRegBtb(AddrPred);
    RegFile#(BtbIndex, Addr) arr <- mkRegFileFull;
    RegFile#(BtbIndex, BtbTag) tagArr <- mkRegFileFull;
    Vector#(BtbEntries, Reg#(Bool)) validArr <- replicateM(mkReg(False));

    function BtbIndex getIndex(Addr pc) = truncate(pc >> 2);
    function BtbTag getTag(Addr pc) = truncateLSB(pc);

    method Addr predPc(Addr pc);
        BtbIndex index = getIndex(pc);
        BtbTag tag = getTag(pc);
        if(validArr[index] && tag == tagArr.sub(index))
            return arr.sub(index);
        else
            return (pc + 4);
    endmethod

    method Action update(Redirect rd);
        let index = getIndex(rd.pc);
        let tag = getTag(rd.pc);
        if(rd.taken) begin
            validArr[index] <= True;
            tagArr.upd(index, tag);
            arr.upd(index, rd.nextPc);
        end else if( tagArr.sub(index) == tag ) begin
            // current instruction has target in btb, so clear it
            validArr[index] <= False;
        end
    endmethod
endmodule



interface DirPred;
    method Bool dirPred(Addr pc);
    method Action update(Addr pc, Bool taken);
endinterface

// XXX Value for quick compilation
typedef 16 BhtEntries;
// typedef 1024 BhtEntries;
typedef Bit#(TLog#(BhtEntries)) BhtIndex;

(* synthesize *)
module mkRegBht(DirPred);
    RegFile#(BhtIndex, Bit#(2)) hist <- mkRegFileFull;
    // When validArr goes from False to true, modify hist to be 2'b01
    Vector#(BhtEntries, Reg#(Bool)) validArr <- replicateM(mkReg(False));

    function BhtIndex getIndex(Addr pc);
        return truncate(pc >> 2);
    endfunction

    // rule specific values
    RegFile#(BhtIndex, Bit#(2))     decode_hist     = hist;
    Vector#(BhtEntries, Reg#(Bool)) decode_validArr = validArr;
    
    RegFile#(BhtIndex, Bit#(2))     commit_hist     = hist;
    Vector#(BhtEntries, Reg#(Bool)) commit_validArr = validArr;
    
    // decode method
    method Bool dirPred(Addr pc);
        let index = getIndex(pc);
        if( decode_validArr[index] == False ) begin
            return False;
        end else begin
            return unpack(decode_hist.sub(index)[1]);
        end
    endmethod

    // commit method
    method Action update(Addr pc, Bool taken);
        if(taken) begin
            let index = getIndex(pc);
            if( commit_validArr[index] == False ) begin
                commit_hist.upd(index, 2'b10);
                commit_validArr[index] <= True;
            end else begin
                let current_hist = commit_hist.sub(index);
                let next_hist = (current_hist == 2'b11) ? 2'b11 : current_hist + 1;
                commit_hist.upd(index, next_hist);
            end
        end else begin
            let index = getIndex(pc);
            if( commit_validArr[index] == False ) begin
                commit_hist.upd(index, 2'b01);
                commit_validArr[index] <= True;
            end else begin
                let current_hist = commit_hist.sub(index);
                let next_hist = (current_hist == 2'b00) ? 2'b00 : current_hist - 1;
                commit_hist.upd(index, next_hist);
            end
        end
    endmethod
endmodule

(* noinline *)
function Maybe#(Addr) decodeBrPred( DecodedInst dInst, Bool histTaken );
    Addr pcPlus4 = dInst.pc + 4;
    Data imm_val = fromMaybe(?, dInst.imm);
    Maybe#(Addr) nextPc = tagged Invalid;
    if( dInst.iType == J ) begin
        Addr jTarget = {pcPlus4[31:28], imm_val[27:0]};
        nextPc = tagged Valid jTarget;
    end else if( dInst.iType == Br ) begin
        if( histTaken ) begin
            nextPc = tagged Valid (pcPlus4 + imm_val);
        end else begin
            nextPc = tagged Valid pcPlus4;
        end
    end else if( dInst.iType == Jr ) begin
        // target is unknown until RegFetch
        nextPc = tagged Invalid;
    end else begin
        nextPc = tagged Valid pcPlus4;
    end
    return nextPc;
endfunction



interface ReturnAddressStack;
    method Action pushAddress(Addr a);
    method ActionValue#(Addr) popAddress();

    // For rolling back
    method Action createCheckpoint(CheckpointTag tag);
    method Action restoreCheckpoint(CheckpointTag tag);
endinterface

typedef 16 RasEntries;
typedef Bit#(TLog#(RasEntries)) RasIndex;

(* synthesize *)
module mkRegReturnAddressStack( ReturnAddressStack );
    Vector#( RasEntries, Reg#(Addr) ) stack <- replicateM(mkReg(0));

    // head points past valid data
    // to gracefully overflow, head is allowed to overflow to 0 and overwrite the oldest data
    Reg#(RasIndex) head <- mkReg(0);

    // for misprediction
    Vector#( NumCheckpoint, Reg#(RasIndex) ) head_checkpoint <- replicateM(mkReg(0));

    RasIndex max_head = fromInteger(valueOf(RasEntries)-1);

    // rule specific values
    Reg#(RasIndex)                          decode_head             = head;
    Vector#(RasEntries, Reg#(Addr))         decode_stack            = stack;
    Vector#(NumCheckpoint, Reg#(RasIndex))  decode_head_checkpoint  = head_checkpoint;

    Reg#(RasIndex)                          mispredict_head             = head;
    Vector#(RasEntries, Reg#(Addr))         mispredict_stack            = stack;
    Vector#(NumCheckpoint, Reg#(RasIndex))  mispredict_head_checkpoint  = head_checkpoint;

    // decode methods
    method Action pushAddress(Addr a);
        decode_stack[decode_head] <= a;
        decode_head <= (decode_head == max_head) ? 0 : decode_head + 1;
    endmethod

    method ActionValue#(Addr) popAddress();
        let new_head = (decode_head == 0) ? max_head : decode_head - 1;
        decode_head <= new_head;
        return decode_stack[new_head];
    endmethod

    method Action createCheckpoint(CheckpointTag tag);
        // This should really be the next cycle's value of head, but I'm not sure if it will ever change when this method is used
        decode_head_checkpoint[tag] <= decode_head;
    endmethod

    // mispredict methods
    method Action restoreCheckpoint(CheckpointTag tag);
        mispredict_head <= mispredict_head_checkpoint[tag];
    endmethod
endmodule
