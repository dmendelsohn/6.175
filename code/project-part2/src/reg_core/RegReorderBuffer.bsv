import Fifo::*;
import RegFifo::*;
import Ehr::*;
import Vector::*;
import Probe::*;
import ProcTypes::*;
import BranchBits::*;

interface ReorderBuffer;
    /// Decode
    method Action enq(RenamedInst in);

    /// Issue
    method IssuedInst execInstToIssue();
    method Action issueExecInst();
    method IssuedInst aluInstToIssue();
    method Action issueAluInst();
    method MemIssuedInst memInstToIssue();
    method Action issueMemInst();

    /// Write Back
    method Action rdyToCommit(ExecutedInst eInst);
    method Action rdyToCommitMem(MemRespInst mInst);

    /// Commit
    method CommittedInst first;
    method Action deq;

    /// Address redirection
    method Action clearBranchBits(CheckpointTag tag);
    // Checkpoint rollback
    // unenq will stop a stepwise rollback
    method Action unenqToCheckpoint(RobIndex pos);
    // Stepwise rollback
    // enqP will be equal to pos after rollback
    method Action unenqStepwiseTo(RobIndex pos);
    // used to get an instruction from the ROB for restoring the renaming table
    // only returns instructions that are not in the execution pipeline
    method RenamedInst last();
    method Action unenq();
    // used to filter messages from redirect fifo
    // if redirection comes from valid rob tag, unenqStepwise is set to the new rob tag
    // and rollback continues. If redirection is from an invalid rob tag, it is ignored
    method Bool isValidRobTag(RobIndex pos);
    method Bool unenqDone();
endinterface

typedef struct {
    RenamedInst         inst;
    Bit#(NumCheckpoint) brBits;
    Bool                brTaken;
    Bool                executed;
    Bool                issued;
} RobRow deriving( Bits, Eq, FShow );

interface RobRowReg;
    interface Reg#(RenamedInst) inst;
    interface BrBitsReg         brBits;
    interface Reg#(Bool)        brTaken;
    interface Reg#(Bool)        executed;
    interface Reg#(Bool)        issued;
    interface Reg#(RobRow)      all;
endinterface

module mkRobRowReg( RobRowReg );
    Reg#(RenamedInst)   _inst      <- mkRegU;
    BrBitsReg           _brBits    <- mkBrBitsReg;
    Reg#(Bool)          _brTaken   <- mkReg(False);
    Reg#(Bool)          _executed  <- mkReg(False);
    Reg#(Bool)          _issued    <- mkReg(False);
    interface inst      = _inst;
    interface brBits    = _brBits;
    interface brTaken   = _brTaken;
    interface executed  = _executed;
    interface issued    = _issued;
    interface Reg all;
        method Action _write( RobRow x );
            _inst       <= x.inst;
            _brBits.all <= x.brBits;
            _brTaken    <= x.brTaken;
            _executed   <= x.executed;
            _issued     <= x.issued;
        endmethod
        method RobRow _read;
            RobRow x;
            x.inst      = _inst;
            x.brBits    = _brBits.all;
            x.brTaken   = _brTaken;
            x.executed  = _executed;
            x.issued    = _issued;
            return x;
        endmethod
    endinterface
endmodule

(* synthesize *)
module mkRegReorderBuffer(ReorderBuffer ifc);
    // storage elements
    Vector#(RobSize, RobRowReg) row     <- replicateM(mkRobRowReg);
    // fifo state elements
    Reg#(Bit#(TLog#(RobSize)))  enqP    <- mkReg(0);
    Reg#(Bit#(TLog#(RobSize)))  deqP    <- mkReg(0);
    Reg#(Bool)                  empty   <- mkReg(True);
    Reg#(Bool)                  full    <- mkReg(False);
    // rollback state
    Reg#(Maybe#(Bit#(TLog#(RobSize)))) rollbackTo <- mkReg(tagged Invalid);

    Vector#(NumPhyReg, Reg#(Bool))  regBusy <- replicateM (mkReg(False));

    // useful value
    Bit#(TLog#(RobSize)) max_index = fromInteger(valueOf(RobSize)-1);

    // probes for debugging
    Probe#(Addr)                    probe_front_pc          <- mkProbe;
    Probe#(Addr)                    probe_front_ppc         <- mkProbe;
    Probe#(IType)                   probe_front_iType       <- mkProbe;
    Probe#(AluFunc)                 probe_front_aluFunc     <- mkProbe;
    Probe#(BrFunc)                  probe_front_brFunc      <- mkProbe;
    Probe#(Maybe#(PhyRegIndex))     probe_front_dstOldName  <- mkProbe;
    Probe#(FullArchRegIndex)        probe_front_dstArchName <- mkProbe;
    Probe#(FullPhyRegIndex)         probe_front_dst         <- mkProbe;
    Probe#(FullPhyRegIndex)         probe_front_src1        <- mkProbe;
    Probe#(PhyRegIndex)             probe_front_src1_gpr    <- mkProbe;
    Probe#(FullPhyRegIndex)         probe_front_src2        <- mkProbe;
    Probe#(PhyRegIndex)             probe_front_src2_gpr    <- mkProbe;
    Probe#(Maybe#(Data))            probe_front_imm         <- mkProbe;
    Probe#(Bit#(NumCheckpoint))     probe_front_brBits      <- mkProbe;
    Probe#(Maybe#(CheckpointTag))   probe_front_checkpoint  <- mkProbe;
    Probe#(Bool)                    probe_front_executed    <- mkProbe;
    Probe#(Bool)                    probe_front_issued      <- mkProbe;

    // Renaming signals used by different sets of rules
    // This is done to make the EHR version much easier to write
    Vector#(RobSize, RobRowReg) decode_row              = row;
    FifoState#(RobSize)         decode_fifo_state       = toFifoState( enqP, deqP, empty, full );

    Vector#(RobSize, RobRowReg) issue_row               = row;
    FifoState#(RobSize)         issue_fifo_state        = toFifoState( enqP, deqP, empty, full );

    Vector#(RobSize, RobRowReg) wb_row                  = row;
    FifoState#(RobSize)         wb_fifo_state           = toFifoState( enqP, deqP, empty, full );

    Vector#(RobSize, RobRowReg) commit_row              = row;
    FifoState#(RobSize)         commit_fifo_state       = toFifoState( enqP, deqP, empty, full );

    Vector#(RobSize, RobRowReg) mispredict_row          = row;
    FifoState#(RobSize)         mispredict_fifo_state   = toFifoState( enqP, deqP, empty, full );


    function Bool isRegReady(FullPhyRegIndex src);
        if( src matches tagged Gpr .r ) begin
            return ((r==0) ? True : !regBusy[r]);
        end else begin
            return True;
        end
    endfunction

    function Action regIsBusy(FullPhyRegIndex src);
        action
            if( src matches tagged Gpr .r ) begin
                regBusy[r] <= True;
            end
        endaction
    endfunction

    function Action regIsNotBusy(FullPhyRegIndex src);
        action
            if( src matches tagged Gpr .r ) begin
                regBusy[r] <= False;
            end
        endaction
    endfunction

    function Bool isAluInst(Integer index);
        return (case (issue_row[index].inst.iType)
                Alu:            True;
                J:              True;
                Jr:             True;
                Br:             True;
                Mfc0:           True;
                Mtc0:           True;
                Unsupported:    True;
                default:        False;
            endcase);
    endfunction

    function Bool isMemInst(Integer index);
        return (case (issue_row[index].inst.iType)
                St:         True;
                Sc:         True;
                Ld:         True;
                Ll:         True;
                default:    False;
            endcase);
    endfunction

    // Prevents issue reordering
    // Later memory instructions can't come before this memory instruction
    function Bool isOrderedMemInst(Integer index);
        return (case (issue_row[index].inst.iType)
                St:         True;
                Sc:         True;
                Ld:         False;
                Ll:         True;
                default:    False;
            endcase);
    endfunction

    // This memory instruction
    function Bool isMemFenceInst(Integer index);
        return (case (issue_row[index].inst.iType)
                St:         False;
                Sc:         True;
                Ld:         False;
                Ll:         False;
                default:    False;
            endcase);
    endfunction

    function Bool issueAtHeadOnly(Integer index);
        return (case (issue_row[index].inst.iType)
                St:             True;
                Sc:             True;
                Mtc0:           True;
                Mfc0:           True;
                Unsupported:    True;
                default:        False;
            endcase);
    endfunction

    // Virtual enqueue pointer
    Bit#(TAdd#(TLog#(RobSize),1)) issue_virtualEnqP = ?;
    if (issue_fifo_state.enqP < issue_fifo_state.deqP) begin
        issue_virtualEnqP = zeroExtend(issue_fifo_state.enqP) + fromInteger(valueOf(RobSize));
    end else if (issue_fifo_state.deqP < issue_fifo_state.enqP) begin
        issue_virtualEnqP = zeroExtend(issue_fifo_state.enqP);
    end else if (issue_fifo_state.deqP==issue_fifo_state.enqP) begin
        if( issue_fifo_state.full ) begin
            issue_virtualEnqP = zeroExtend(issue_fifo_state.enqP) + fromInteger(valueOf(RobSize));
        end else begin
            issue_virtualEnqP = zeroExtend(issue_fifo_state.enqP);
        end
    end

//------------------------------------------------------------------------------
    // Combinatorial logic to know if an instruction is ready to be issued to
    // the alu pipeline
    Vector#(RobSize, Bool) alu_ready_signal;
    Vector#(RobSize, Bool) alu_ready_first_pass;
    Vector#(RobSize, Bool) alu_ready_second_pass;
    Maybe#(Bit#(TLog#(RobSize))) alu_inst_to_issue = tagged Invalid;

    for( Integer i = 0 ; i < valueOf(RobSize) ; i = i+1 ) begin
        alu_ready_signal[i] = isAluInst(i)
                                && !issue_row[i].issued
                                && isRegReady(issue_row[i].inst.src1)
                                && isRegReady(issue_row[i].inst.src2)
                                && (issueAtHeadOnly(i) ? (fromInteger(i) == issue_fifo_state.deqP) : True);
    end

    for( Integer i = 0 ; i < valueOf(RobSize) ; i = i+1 ) begin
        alu_ready_first_pass[i] = alu_ready_signal[i] && (fromInteger(i) >= issue_fifo_state.deqP) && (fromInteger(i) < issue_virtualEnqP);
        alu_ready_second_pass[i] = alu_ready_signal[i] && (fromInteger(i + valueOf(RobSize)) < issue_virtualEnqP);
    end

    // find slot to issue
    for( Integer i = valueOf(RobSize)-1 ; i >= 0 ; i = i-1 ) begin
        if( alu_ready_second_pass[i] ) begin
            alu_inst_to_issue = tagged Valid fromInteger(i);
        end
    end
    for( Integer i = valueOf(RobSize)-1 ; i >= 0 ; i = i-1 ) begin
        if( alu_ready_first_pass[i] ) begin
            alu_inst_to_issue = tagged Valid fromInteger(i);
        end
    end

//------------------------------------------------------------------------------
    // Combinatorial logic to know if an instruction is ready to be issued to
    // the mem pipeline
    Vector#(RobSize, Bool) mem_dep_free_first_pass;
    Vector#(RobSize, Bool) mem_dep_free_second_pass;
    Vector#(RobSize, Bool) mem_ready_signal;
    Vector#(RobSize, Bool) mem_ready_first_pass;
    Vector#(RobSize, Bool) mem_ready_second_pass;
    Maybe#(Bit#(TLog#(RobSize))) mem_inst_to_issue = tagged Invalid;

    mem_dep_free_first_pass[0] = True;
    for( Integer i = 1 ; i < valueOf(RobSize) ; i = i+1 ) begin
        // // In order for i to be dependency free, i-1 must be dependency free and either not a memory instruction or already in exec
        // mem_dep_free_first_pass[i] = mem_dep_free_first_pass[i-1] && (!(isMemInst(i-1) && fromInteger(i-1) >= issue_fifo_state.deqP ) || issue_row[i-1].issued);

        // Allow for loads to be reordered with loads, but not stores
        mem_dep_free_first_pass[i] = mem_dep_free_first_pass[i-1] && (!(isOrderedMemInst(i-1) && fromInteger(i-1) >= issue_fifo_state.deqP ) || issue_row[i-1].issued);
    end
    mem_dep_free_second_pass[0] = mem_dep_free_first_pass[valueOf(RobSize)-1] && (!isOrderedMemInst(valueOf(RobSize)-1) || issue_row[valueOf(RobSize)-1].issued);
    for( Integer i = 1 ; i < valueOf(RobSize) ; i = i+1 ) begin
        // mem_dep_free_second_pass[i] = mem_dep_free_second_pass[i-1] && (!isOrderedMemInst(i-1) || issue_row[i-1].issued);

        // Allow for loads to be reordered with loads, but not stores
        mem_dep_free_second_pass[i] = mem_dep_free_second_pass[i-1] && (!isOrderedMemInst(i-1) || issue_row[i-1].issued);
    end

    for( Integer i = 0 ; i < valueOf(RobSize) ; i = i+1 ) begin
        mem_ready_signal[i] = isMemInst(i)
                                && !issue_row[i].issued
                                && isRegReady(issue_row[i].inst.src1)
                                && isRegReady(issue_row[i].inst.src2)
                                && (issueAtHeadOnly(i) ? (fromInteger(i) == issue_fifo_state.deqP) : True);
    end

    for( Integer i = 0 ; i < valueOf(RobSize) ; i = i+1 ) begin
        mem_ready_first_pass[i] = mem_dep_free_first_pass[i] && mem_ready_signal[i] && (fromInteger(i) >= issue_fifo_state.deqP) && (fromInteger(i) < issue_virtualEnqP);
        mem_ready_second_pass[i] = mem_dep_free_second_pass[i] && mem_ready_signal[i] && (fromInteger(i + valueOf(RobSize)) < issue_virtualEnqP);
    end

    for( Integer i = valueOf(RobSize)-1 ; i >= 0 ; i = i-1 ) begin
        if( mem_ready_second_pass[i] ) begin
            mem_inst_to_issue = tagged Valid fromInteger(i);
        end
    end
    for( Integer i = valueOf(RobSize)-1 ; i >= 0 ; i = i-1 ) begin
        if( mem_ready_first_pass[i] ) begin
            mem_inst_to_issue = tagged Valid fromInteger(i);
        end
    end

//--------------------------------------------------
    // Exec inst to issue
    Maybe#(Bit#(TLog#(RobSize))) exec_inst_to_issue = tagged Invalid;

    // find slot to issue
    for( Integer i = valueOf(RobSize)-1 ; i >= 0 ; i = i-1 ) begin
        if( alu_ready_second_pass[i] || mem_ready_second_pass[i] ) begin
            exec_inst_to_issue = tagged Valid fromInteger(i);
        end
    end
    for( Integer i = valueOf(RobSize)-1 ; i >= 0 ; i = i-1 ) begin
        if( alu_ready_first_pass[i] || mem_ready_first_pass[i] ) begin
            exec_inst_to_issue = tagged Valid fromInteger(i);
        end
    end
//--------------------------------------------------

    // Commit methods
    method Action clearBranchBits(CheckpointTag tag);
        for(Integer i=0; i<valueOf(RobSize); i = i + 1) begin
            commit_row[i].brBits.b[tag] <= 0;
        end
    endmethod

    method CommittedInst first() if( !commit_fifo_state.empty && commit_row[commit_fifo_state.deqP].executed && !isValid(rollbackTo) );
        let cInst = toCommittedInst( commit_row[commit_fifo_state.deqP].inst );
        cInst.brTaken = commit_row[commit_fifo_state.deqP].brTaken;
        return cInst;
    endmethod

    method Action deq() if( !commit_fifo_state.empty && commit_row[commit_fifo_state.deqP].executed && !isValid(rollbackTo) );
        // update deqP, full, and empty
        let nextDeqP = (commit_fifo_state.deqP == max_index) ? 0 : commit_fifo_state.deqP + 1;
        commit_fifo_state.deqP <= nextDeqP;
        commit_fifo_state.full <= False;
        commit_fifo_state.empty <= (nextDeqP == commit_fifo_state.enqP);
    endmethod

    // WriteBack method
    method Action rdyToCommit(ExecutedInst eInst);
        wb_row[eInst.robTag].executed <= True;
        regIsNotBusy( wb_row[eInst.robTag].inst.dst );
        wb_row[eInst.robTag].brTaken <= eInst.brTaken;
    endmethod

    method Action rdyToCommitMem(MemRespInst mInst);
        wb_row[mInst.robTag].executed <= True;
        regIsNotBusy( wb_row[mInst.robTag].inst.dst );
        wb_row[mInst.robTag].brTaken <= False;
    endmethod

    // Issue methods
    method IssuedInst execInstToIssue() if ( isValid(exec_inst_to_issue) && !isValid(rollbackTo) );
        let index = fromMaybe(?,exec_inst_to_issue);
        let ret = toIssuedInst(issue_row[index].inst);
        ret.brBits = issue_row[index].brBits.all;
        ret.robTag = index;
        return ret;
    endmethod
    method Action issueExecInst() if ( isValid(exec_inst_to_issue) && !isValid(rollbackTo) );
        let index = fromMaybe(?,exec_inst_to_issue);
        issue_row[index].issued <= True;
    endmethod

    method IssuedInst aluInstToIssue() if ( isValid(alu_inst_to_issue) && !isValid(rollbackTo) );
        let index = fromMaybe(?,alu_inst_to_issue);
        let ret = toIssuedInst(issue_row[index].inst);
        ret.brBits = issue_row[index].brBits.all;
        ret.robTag = index;
        return ret;
    endmethod
    method Action issueAluInst() if ( isValid(alu_inst_to_issue) && !isValid(rollbackTo) );
        let index = fromMaybe(?,alu_inst_to_issue);
        issue_row[index].issued <= True;
    endmethod

    method MemIssuedInst memInstToIssue() if ( isValid(mem_inst_to_issue) && !isValid(rollbackTo) );
        let index = fromMaybe(?,mem_inst_to_issue);
        let ret = toMemIssuedInst(issue_row[index].inst);
        ret.brBits = issue_row[index].brBits.all;
        ret.robTag = index;
        return ret;
    endmethod
    method Action issueMemInst() if ( isValid(mem_inst_to_issue) && !isValid(rollbackTo) );
        let index = fromMaybe(?,mem_inst_to_issue);
        issue_row[index].issued <= True;
        // If it is a store instruction, it is not coming back
        if( issue_row[index].inst.iType == St ) begin
            issue_row[index].executed <= True;
        end
    endmethod

    // Decode method
    method Action enq(RenamedInst x) if( !decode_fifo_state.full && !isValid(rollbackTo) );
        decode_row[decode_fifo_state.enqP].inst <= x;
        decode_row[decode_fifo_state.enqP].brBits.all <= x.brBits;
        regIsBusy( x.dst );
        decode_row[decode_fifo_state.enqP].issued <= False;
        decode_row[decode_fifo_state.enqP].executed <= False;

        // Increment enqueue pointer
        let newEnqP = (decode_fifo_state.enqP == max_index) ? 0 : decode_fifo_state.enqP + 1;
        decode_fifo_state.enqP <= newEnqP;
        if( newEnqP == deqP ) begin
            decode_fifo_state.empty <= False;
            decode_fifo_state.full <= True;
        end else begin
            decode_fifo_state.empty <= False;
            decode_fifo_state.full <= False;
        end
    endmethod

    // Mispredict methods
    method Action unenqToCheckpoint(Bit#(TLog#(RobSize)) tag);
        enqP <= tag;
        if( tag == deqP ) begin
            // enqP and deqP will be equal at the end of this clock
            // cycle, so the reorder buffer will either be full or
            // empty.
            if( full == False ) begin
                // after normal enq/deq, the rob not full, so it will
                // be empty after unenqueuing
                empty <= True;
                full <= False;
            end else begin
                // after normal enq/deq, the rob was full, so it will
                // still be full after unenqueuing
                full <= True;
                empty <= False;
                // reasoning: full rob => nothing dequeued =>
                // mispredicted branch is still in rob => rob not empty
                // => rob still full
            end
        end else begin
            // enqP != deqP, so ROB is neither full nor empty.
            empty <= False;
            full <= False;
        end

        // check to see if rollbackTo is no longer a valid robTag
        let tail = tag;
        let head = deqP;
        if( isValid(rollbackTo) ) begin
            let rollbackTag = fromMaybe(?, rollbackTo);
            if( tail > head ) begin
                if( rollbackTag >= tail || rollbackTag < head ) begin
                    rollbackTo <= tagged Invalid;
                end
            end else if( tail < head ) begin
                if( rollbackTag >= tail && rollbackTag < head ) begin
                    rollbackTo <= tagged Invalid;
                end
            end
        end
    endmethod

    method Action unenqStepwiseTo(Bit#(TLog#(RobSize)) pos);
        if( pos != enqP ) begin
            rollbackTo <= tagged Valid pos;
        end
    endmethod

    method RenamedInst last() if(isValid(rollbackTo) && (row[enqP==0?max_index:enqP-1].executed || !row[enqP==0?max_index:enqP-1].issued));
        let unenqP = (enqP == 0) ? max_index : enqP - 1;
        return row[unenqP].inst;
    endmethod

    method Action unenq() if(isValid(rollbackTo) && (row[enqP==0?max_index:enqP-1].executed || !row[enqP==0?max_index:enqP-1].issued));
        let unenqP = (enqP == 0) ? max_index : enqP - 1;

        enqP <= unenqP;
        if( unenqP == deqP ) begin
            // enqP and deqP will be equal at the end of this clock
            // cycle, so the reorder buffer will either be full or
            // empty.
            if( full == False ) begin
                // after normal enq/deq, the rob not full, so it will
                // be empty after unenqueuing
                empty <= True;
                full <= False;
            end else begin
                // after normal enq/deq, the rob was full, so it will
                // still be full after unenqueuing
                full <= True;
                empty <= False;
                // reasoning: full rob => nothing dequeued =>
                // mispredicted branch is still in rob => rob not empty
                // => rob still full
            end
        end else begin
            // enqP != deqP, so ROB is neither full nor empty.
            empty <= False;
            full <= False;
        end

        if( isValid(rollbackTo) && fromMaybe(?,rollbackTo) == unenqP ) begin
            rollbackTo <= tagged Invalid;
        end
    endmethod

    method Bool isValidRobTag(Bit#(TLog#(RobSize)) pos);
        let head = deqP;
        let tail = isValid(rollbackTo) ? fromMaybe(?,rollbackTo) : enqP;
        if( head < tail ) begin
            return (pos >= head) && (pos < tail);
        end else if( head > tail ) begin
            return (pos >= head) || (pos < tail);
        end else if( !isValid(rollbackTo) ) begin
            return full;
        end else begin
            // head == tail, rollbackTo is valid, guess that the ROB is empty
            // $display("ReorderBuffer::isValidRobTag : [WARNING] head == tail after considering rollbackTo -- Assuming invalid rob tag");
            return False;
        end
    endmethod

    method Bool unenqDone();
        return !isValid(rollbackTo);
    endmethod
endmodule

