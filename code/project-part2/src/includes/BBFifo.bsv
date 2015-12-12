// branch bits fifos
//   A set of fifos for killing instructions based on branch bits and clearing
//   branch bits in place.

import Ehr::*;
import Vector::*;
import TypeClasses::*;
import ProcTypes::*;
import RevertingVirtualReg::*;

interface BBFifo#(numeric type n, type t);
    method Bool canEnq;
    method Action enq(t x);
    method Bool canDeq;
    method Action deq;
    method t first;
    method Action clear;
    // branch bits methods
    method Action badBranch( CheckpointTag x );
    method Action goodBranch( CheckpointTag x );
endinterface

//////////////////////////////////////////////////
// Conflict free bbfifo with conflict free clear

// badBranch kills the instruction in place
// goodBranch clears the associated branch bit in place

// {enq, canEnq} CF {deq, canDeq, first}
// goodBranch CF badBranch
// clear CF {goodBranch, badBranch}
// {enq, canEnq, deq, canDeq, first} < {goodBranch, badBranch, clear}
module mkCFBBFifo( BBFifo#(n, t) ) provisos (Bits#(t,tSz), HasBranchBits#(t));
    // n is size of fifo
    // t is type of fifo

    // storage elements
    Vector#(n, Reg#(t))     data    <- replicateM(mkRegU);
    Vector#(n, Reg#(Bool))  valid   <- replicateM(mkReg(False));
    Reg#(Bit#(TLog#(n)))    enqP    <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP    <- mkReg(0);

    // requests
    Ehr#(2, Maybe#(t))              enqReq          <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(void))           deqReq          <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(void))           clearReq        <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(CheckpointTag))  badBranchReq    <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(CheckpointTag))  goodBranchReq   <- mkEhr(tagged Invalid);

    // reverting virtual registers to force {canEnq, enq, canDeq, deq, first} < {clear, goodBranch, badBranch}
    Reg#(Bool)  c_rvr   <- mkRevertingVirtualReg(True);
    Reg#(Bool)  gb_rvr  <- mkRevertingVirtualReg(True);
    Reg#(Bool)  bb_rvr  <- mkRevertingVirtualReg(True);

    // useful value
    Bit#(TLog#(n))      max_index   = fromInteger(valueOf(n)-1);

    // some combinational logic
    Bool can_deq = valid[deqP];
    Bool can_enq = !valid[enqP];

    Bool notEmpty = readVReg(valid) != replicate(False);
    
    Bool scheduling_rvrs = c_rvr && gb_rvr && bb_rvr;

    // Update the state of the fifo to match any enqueue or dequeue
    // These attributes are statically checked by the compiler
    (* fire_when_enabled *)         // WILL_FIRE == CAN_FIRE
    (* no_implicit_conditions *)    // CAN_FIRE == guard (True)
    rule canonicalize;
        // handle clear requests first
        if( isValid(clearReq[1]) ) begin
            // Set the fifo to an empty state
            enqP <= 0;
            deqP <= 0;
            writeVReg(valid, replicate(False));
        end else begin
            Vector#(n, t) new_data = readVReg(data);
            Vector#(n, Bool) new_valid = readVReg(valid);
            let new_enqP = enqP;
            let new_deqP = deqP;

            // Enqueue data
            if( isValid(enqReq[1]) ) begin
                let x = fromMaybe(?, enqReq[1]);
                new_data[ enqP ] = x;
                new_valid[ enqP ] = True;
                new_enqP = (enqP == max_index) ? 0 : enqP + 1;
            end

            // Dequeue data
            if( isValid(deqReq[1]) ) begin
                new_valid[ deqP ] = False;
                new_deqP = (deqP == max_index) ? 0 : deqP + 1;
            end else if( !valid[deqP] && (deqP != enqP || notEmpty) ) begin
                // move the deq pointer anyway to remove invalid bubbles
                new_deqP = (deqP == max_index) ? 0 : deqP + 1;
            end

            // Branch Bit functions
            // These work on new_data to update newly enqueued data
            if( isValid(badBranchReq[1]) ) begin
                // Tag instructions as invalid in the fifo
                // Don't need to clear valid bits
                for( Integer i = 0 ; i < valueOf(n) ; i = i + 1 ) begin
                    if( getBranchBit(new_data[i], fromMaybe(?, badBranchReq[1])) ) begin
                        new_valid[i] = False;
                    end
                end
            end
            if( isValid(goodBranchReq[1]) ) begin
                // clear branch bits for all data in the fifo
                for( Integer i = 0 ; i < valueOf(n) ; i = i + 1 ) begin
                    new_data[i] = clearBranchBit( new_data[i], fromMaybe(?, goodBranchReq[1]) );
                end
            end

            // Sanity check
            // If goodBranch and badBranch are called for the same location, then the calls are not commutitive so throw an error
            if( goodBranchReq[1] matches tagged Valid .x &&& badBranchReq[1] matches tagged Valid .y &&& x == y ) begin
                $fwrite(stderr, "mkCFBBFifo : [ERROR] goodBranch and badBranch were called in the same cycle for the same branch bit");
                $finish;
            end

            // update data, valid, enqP, and deqP
            writeVReg(data, new_data);
            writeVReg(valid, new_valid);
            enqP <= new_enqP;
            deqP <= new_deqP;
        end
        // Clear Requests
        enqReq[1] <= tagged Invalid;
        deqReq[1] <= tagged Invalid;
        clearReq[1] <= tagged Invalid;
        badBranchReq[1] <= tagged Invalid;
        goodBranchReq[1] <= tagged Invalid;
    endrule

    method Bool canEnq if( scheduling_rvrs ) = can_enq;

    method Action enq(t x) if( can_enq && scheduling_rvrs );
        // Tell later stages an enqueue was requested
        enqReq[0] <= tagged Valid x;
    endmethod

    method Bool canDeq if( scheduling_rvrs ) = can_deq;

    method Action deq if( can_deq && scheduling_rvrs );
        // Tell later stages a dequeue was requested
        deqReq[0] <= tagged Valid;
    endmethod

    method t first if( can_deq && scheduling_rvrs );
        return data[ deqP ];
    endmethod

    method Action clear;
        // forces clear > {canEnq, enq, canDeq, deq, first}
        c_rvr <= False;
        // Tell later stages a clear was requested
        clearReq[0] <= tagged Valid;
    endmethod

    method Action badBranch( CheckpointTag x );
        // forces badBranch > {canEnq, enq, canDeq, deq, first}
        bb_rvr <= False;
        // Tell later stages a bad branch was requested
        badBranchReq[0] <= tagged Valid x;
    endmethod

    method Action goodBranch( CheckpointTag x );
        // forces goodBranch > {canEnq, enq, canDeq, deq, first}
        gb_rvr <= False;
        // Tell later stages a good branch was requested
        goodBranchReq[0] <= tagged Valid x;
    endmethod
endmodule


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

///////////////////////////////////////////
// Slightly different conflict free bbfifo

// badBranch kills the instruction in place
// goodBranch clears the associated branch bit in place

// {enq, canEnq} CF {deq, canDeq, first}
// clear CF badBranch
// goodBranch < first
// {enq, canEnq, deq, canDeq, first} < {badBranch, clear}
module mkAltBBFifo( BBFifo#(n, t) ) provisos (Bits#(t,tSz), HasBranchBits#(t));
    // n is size of fifo
    // t is type of fifo

    // storage elements
    Vector#(n, Reg#(t))     data    <- replicateM(mkRegU);
    Vector#(n, Reg#(Bool))  valid   <- replicateM(mkReg(False));
    Reg#(Bit#(TLog#(n)))    enqP    <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP    <- mkReg(0);

    // requests
    Ehr#(2, Maybe#(t))              enqReq          <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(void))           deqReq          <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(void))           clearReq        <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(CheckpointTag))  badBranchReq    <- mkEhr(tagged Invalid);
    Ehr#(2, Maybe#(CheckpointTag))  goodBranchReq   <- mkEhr(tagged Invalid);

    // reverting virtual registers to force {canEnq, enq, canDeq, deq, first} < {clear, goodBranch, badBranch}
    Reg#(Bool)  c_rvr   <- mkRevertingVirtualReg(True);
    Reg#(Bool)  gb_rvr  <- mkRevertingVirtualReg(True);
    Reg#(Bool)  bb_rvr  <- mkRevertingVirtualReg(True);

    // useful value
    Bit#(TLog#(n))      max_index   = fromInteger(valueOf(n)-1);

    // some combinational logic
    Bool can_deq = valid[deqP];
    Bool can_enq = !valid[enqP];

    Bool notEmpty = readVReg(valid) != replicate(False);
    
    Bool scheduling_rvrs = c_rvr && bb_rvr;

    // Update the state of the fifo to match any enqueue or dequeue
    // These attributes are statically checked by the compiler
    (* fire_when_enabled *)         // WILL_FIRE == CAN_FIRE
    (* no_implicit_conditions *)    // CAN_FIRE == guard (True)
    rule canonicalize;
        // handle clear requests first
        if( isValid(clearReq[1]) ) begin
            // Set the fifo to an empty state
            enqP <= 0;
            deqP <= 0;
            writeVReg(valid, replicate(False));
        end else begin
            Vector#(n, t) new_data = readVReg(data);
            Vector#(n, Bool) new_valid = readVReg(valid);
            let new_enqP = enqP;
            let new_deqP = deqP;

            // Enqueue data
            if( isValid(enqReq[1]) ) begin
                let x = fromMaybe(?, enqReq[1]);
                new_data[ enqP ] = x;
                new_valid[ enqP ] = True;
                new_enqP = (enqP == max_index) ? 0 : enqP + 1;
            end

            // Dequeue data
            if( isValid(deqReq[1]) ) begin
                new_valid[ deqP ] = False;
                new_deqP = (deqP == max_index) ? 0 : deqP + 1;
            end else if( !valid[deqP] && (deqP != enqP || notEmpty) ) begin
                // move the deq pointer anyway to remove invalid bubbles
                new_deqP = (deqP == max_index) ? 0 : deqP + 1;
            end

            // Branch Bit functions
            // These work on new_data to update newly enqueued data
            if( isValid(badBranchReq[1]) ) begin
                // Tag instructions as invalid in the fifo
                // Don't need to clear valid bits
                for( Integer i = 0 ; i < valueOf(n) ; i = i + 1 ) begin
                    if( getBranchBit(new_data[i], fromMaybe(?, badBranchReq[1])) ) begin
                        new_valid[i] = False;
                    end
                end
            end
            if( isValid(goodBranchReq[1]) ) begin
                // clear branch bits for all data in the fifo
                for( Integer i = 0 ; i < valueOf(n) ; i = i + 1 ) begin
                    new_data[i] = clearBranchBit( new_data[i], fromMaybe(?, goodBranchReq[1]) );
                end
            end

            // Sanity check
            // If goodBranch and badBranch are called for the same location, then the calls are not commutitive so throw an error
            if( goodBranchReq[1] matches tagged Valid .x &&& badBranchReq[1] matches tagged Valid .y &&& x == y ) begin
                $fwrite(stderr, "mkCFBBFifo : [ERROR] goodBranch and badBranch were called in the same cycle for the same branch bit");
                $finish;
            end

            // update data, valid, enqP, and deqP
            writeVReg(data, new_data);
            writeVReg(valid, new_valid);
            enqP <= new_enqP;
            deqP <= new_deqP;
        end
        // Clear Requests
        enqReq[1] <= tagged Invalid;
        deqReq[1] <= tagged Invalid;
        clearReq[1] <= tagged Invalid;
        badBranchReq[1] <= tagged Invalid;
        goodBranchReq[1] <= tagged Invalid;
    endrule

    method Bool canEnq if( scheduling_rvrs ) = can_enq;

    method Action enq(t x) if( can_enq && scheduling_rvrs );
        // Tell later stages an enqueue was requested
        enqReq[0] <= tagged Valid x;
    endmethod

    method Bool canDeq if( scheduling_rvrs ) = can_deq;

    method Action deq if( can_deq && scheduling_rvrs );
        // Tell later stages a dequeue was requested
        deqReq[0] <= tagged Valid;
    endmethod

    method t first if( can_deq );
        t ret = data[deqP];
        if( isValid(goodBranchReq[1]) ) begin
            ret = clearBranchBit( ret, fromMaybe(?, goodBranchReq[1]) );
        end
        return ret;
    endmethod

    method Action clear;
        // forces clear > {canEnq, enq, canDeq, deq, first}
        c_rvr <= False;
        // Tell later stages a clear was requested
        clearReq[0] <= tagged Valid;
    endmethod

    method Action badBranch( CheckpointTag x );
        // forces badBranch > {canEnq, enq, canDeq, deq, first}
        bb_rvr <= False;
        // Tell later stages a bad branch was requested
        badBranchReq[0] <= tagged Valid x;
    endmethod

    method Action goodBranch( CheckpointTag x );
        // forces goodBranch > {canEnq, enq, canDeq, deq, first}
        gb_rvr <= False;
        // Tell later stages a good branch was requested
        goodBranchReq[0] <= tagged Valid x;
    endmethod
endmodule
