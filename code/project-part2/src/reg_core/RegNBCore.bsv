import GetPut::*;
import ClientServer::*;
import ProcTypes::*;
import Fifo::*;
import RegFifo::*;
import BBFifo::*;
import RegBBFifo::*;
import RegCop::*;
import RegReorderBuffer::*;
import RegRenamingTable::*;
import Decode::*;
import MemUtil::*;
import MemInit::*;
import RegAddrPred::*;
import TypeClasses::*;
import RFile::*;
import Vector::*;

import RegNBFetchPipeline::*;
import RegNBMemoryPipeline::*;
import RegAluPipeline::*;

(* synthesize *)
module mkRegNBCore(CoreIndex coreid, NBCore ifc);
    // Caches
    Fifo#(2, Addr)              iCache_req          <- mkRegFifo;
    Fifo#(2, Data)              iCache_resp         <- mkRegFifo;
    Fifo#(2, NBCacheReq)        dCache_req          <- mkRegFifo;
    Fifo#(2, NBCacheResp)       dCache_resp         <- mkRegFifo;
    NBICache                    iCache              =  toProcMemory( iCache_req, iCache_resp );
    NBCache                     dCache              =  toProcMemory( dCache_req, dCache_resp );

    // Fetch Pipeline
    Fifo#(2, FetchedInst)       fromInstFetchFifo   <- mkRegFifo;
    Fifo#(2, Redirect)          fetchRedirectFifo   <- mkRegFifo;
    FetchPipeline               fetch               <- mkRegNBFetchPipeline(
                                                        fromInstFetchFifo,
                                                        fetchRedirectFifo,
                                                        iCache );

    // Register File
    RFile                       rf                  <- mkRFile();

    // Alu Pipeline
    // Conflicting BBFifos
    BBFifo#(2, IssuedInst)      toAluFifo           <- mkRegBBFifo;
    BBFifo#(2, ExecutedInst)    fromAluFifo         <- mkRegBBFifo;
    BBFifo#(2, Mispredict)      execMispredictFifo  <- mkRegBBFifo;
    Reg#(Maybe#(Mispredict))    mispredictReg       <- mkReg(tagged Invalid);
    Cop                         cop0                <- mkRegCop(coreid);
    AluPipeline                 alu                 <- mkRegAluPipeline(
                                                        toAluFifo,
                                                        fromAluFifo,
                                                        execMispredictFifo,
                                                        cop0,
                                                        rf);

    // NB Memory Pipeline
    // Conflicting BBFifos
    BBFifo#(2, MemIssuedInst)   toMemFifo           <- mkRegBBFifo;
    BBFifo#(2, MemRespInst)     fromMemFifo         <- mkRegBBFifo;
    NBMemoryPipeline            mem                 <- mkRegNBMemoryPipeline(
                                                        toMemFifo,
                                                        fromMemFifo,
                                                        cop0,
                                                        dCache,
                                                        rf);

    // Branch Prediction Modules
    DirPred                     bht                 <- mkRegBht;
    ReturnAddressStack          ras                 <- mkRegReturnAddressStack;

    // Epochs for decode stage
    Reg#(ExecuteEpoch)          eEpoch              <- mkReg(0);
    Reg#(DecodeEpoch)           dEpoch              <- mkReg(0);

    // Reordering Modules
    ReorderBuffer               rob                 <- mkRegReorderBuffer;
    RenamingTable               rt                  <- mkRegRenamingTable;

    // Debugging
    Reg#(File) file <- mkReg(InvalidFile);
    Reg#(Bool) file_opened <- mkReg(False);
    rule doDebug(!file_opened);
        // If you only have two cores, BSV complains about the literals "2" and "3" below
        Bit#(32) coreid_ext = zeroExtend(coreid);
        String filename = (case(coreid_ext)
                                0: "core_0_trace.log";
                                1: "core_1_trace.log";
                                2: "core_2_trace.log";
                                3: "core_3_trace.log";
                                default: "core_others_trace.log";
                            endcase);
        let x <- $fopen(filename, "w");
        if( x != InvalidFile ) begin
            file <= x;
            file_opened <= True;
        // end else begin
        //     $fwrite(stderr, "ERROR: Cannot open %s\n", filename);
        //     $finish;
        end
    endrule

    rule doDecode( !execMispredictFifo.canDeq() && !isValid(mispredictReg) );
        $display("doDecode");
        let fInst = fromInstFetchFifo.first;
        fromInstFetchFifo.deq();
        // Only decode if the epochs match
        if( fInst.eEpoch == eEpoch && fInst.dEpoch == dEpoch ) begin
            // $display("doDecode: pc = 0x%h, inst = 0x%h\n\t", fInst.pc, fInst.inst, showInst(fInst.inst) );
            let dInst = decode(fInst);

            // Lets do some branch prediction
            let predPC = decodeBrPred(dInst, bht.dirPred(dInst.pc));

            if( (dInst.iType == J || dInst.iType == Jr) && isGpr(dInst.dst) ) begin
                // Jump and link instruction -- (this includes jalr)
                // push pc+4 onto the stack
                ras.pushAddress( dInst.pc + 4 );
            end else if( dInst.iType == Jr ) begin
                // Jump register instruction -- (this does not include jalr)
                // pop a prediction from the stack
                let stackPc <- ras.popAddress;
                predPC = tagged Valid stackPc;
            end

            if( isValid(predPC) && (fromMaybe(?,predPC) != dInst.ppc) ) begin
                // do redirection
                dInst.ppc = fromMaybe(?,predPC);
                dEpoch <= nextEpoch(dEpoch);
                fetchRedirectFifo.enq( Redirect{
                                            pc:     dInst.pc,
                                            nextPc: fromMaybe(?,predPC),
                                            taken:  (dInst.ppc != (dInst.pc+4)), // not needed
                                            eEpoch: eEpoch,
                                            dEpoch: nextEpoch(dEpoch) } );
            end

            // Lets rename the instruction
            let renamedInst = toRenamedInst(dInst);
            renamedInst.src1 =
                case (dInst.src1) matches
                    tagged Invalid : tagged Invalid;
                    tagged Cop0 .a : tagged Cop0 a;
                    tagged Gpr .b  : tagged Gpr (rt.lookup1(b));
                endcase;
            renamedInst.src2 =
                case (dInst.src2) matches
                    tagged Invalid : tagged Invalid;
                    tagged Cop0 .a : tagged Cop0 a;
                    tagged Gpr .b  : tagged Gpr (rt.lookup2(b));
                endcase;
            case (dInst.dst) matches
                tagged Invalid : noAction;
                tagged Cop0 .a : renamedInst.dst = tagged Cop0 a;
                tagged Gpr .b  : begin
                                    let oldName = rt.lookup3(b);
                                    let newName <- rt.rename(b);
                                    renamedInst.dstOldName = tagged Valid oldName;
                                    renamedInst.dst = tagged Gpr newName;
                                 end
            endcase
            // $display("\toriginal src1 = ", fshow(dInst.src1), ", src2 = ", fshow(dInst.src2), ", dst = ", fshow(dInst.dst) );
            // $display("\trenamed src1 = ", fshow(renamedInst.src1), ", src2 = ", fshow(renamedInst.src2), ", dst = ", fshow(renamedInst.dst) );

            // If this code is commented out, the processor is not using checkpoints and is instead rolling back for each misprediction
            // if(dInst.brFunc != NT) begin
            //     let cp <- rt.makeCheckpoint();
            //     renamedInst.checkpoint = tagged Valid cp;
            //     // make a checkpoint in the ras also
            //     ras.createCheckpoint( cp );
            // end
            renamedInst.brBits = rt.curBranchBits();
            // $display("\tbrBits = %b", renamedInst.brBits);
            rob.enq(renamedInst);
        end else begin
            // $display("doDecode: Wrong path instruction");
        end
    endrule

    rule doIssueAlu;
        $display("doIssueAlu");
        let issuedInst = rob.aluInstToIssue();
        rob.issueAluInst;
        toAluFifo.enq( issuedInst );
    endrule

    rule doIssueMem;
        $display("doIssueMem");
        let issuedInst = rob.memInstToIssue();
        rob.issueMemInst;
        toMemFifo.enq( issuedInst );
    endrule

    rule doWBAlu(!execMispredictFifo.canDeq && !isValid(mispredictReg));
        $display("doWBAlu");
        let aluInst = fromAluFifo.first;
        fromAluFifo.deq;

        // $display("doWBAlu: pc = %h,", aluInst.pc);

        rob.rdyToCommit(aluInst);
    endrule

    rule doWBMem(!execMispredictFifo.canDeq && !isValid(mispredictReg));
        $display("doWBMem");
        let memInst = fromMemFifo.first;
        fromMemFifo.deq;

        // $display("doWBMem: rob tag = %h,", memInst.robTag);

        rob.rdyToCommitMem(memInst);
    endrule

    rule doCommit( !execMispredictFifo.canDeq() && !isValid(mispredictReg) );
        $display("doCommit");
        let committedInst = rob.first;
        rob.deq;
        cop0.commitInst;

        // $display("doCommit: pc = 0x%h", committedInst.pc );

        // write trace to file
        $fwrite(file, "%0t : PC = 0x%0x, iType = ", $time, committedInst.pc, fshow(committedInst.iType), "\n");

        if( isValid(committedInst.dstOldName) ) begin
            // Free the old register
            rt.free1( fromMaybe(?, committedInst.dstOldName) );
        end

        if( isValid(committedInst.checkpoint) ) begin
            // Committing a branch instruction with a valid checkpoint, so free that checkpoint
            rt.freeCheckpoint( fromMaybe(?, committedInst.checkpoint) );
            // And clear the corresponding branch bits
            rob.clearBranchBits( fromMaybe(?, committedInst.checkpoint) );
            // exec.goodBranch( fromMaybe(?, committedInst.checkpoint) );
            alu.goodBranch( fromMaybe(?, committedInst.checkpoint) );
            mem.goodBranch( fromMaybe(?, committedInst.checkpoint) );
        end

        // branch predictor training
        if( committedInst.brFunc != NT ) begin
            // bht training for branches only
            if( committedInst.iType == Br ) begin
                bht.update( committedInst.pc, committedInst.brTaken );
            end
            // btb training
            // done through misprediction from execute stage
        end
    endrule

    rule doMispredict_get(!isValid(mispredictReg));
        //$display("doMispredict_get");
        let mispredict = execMispredictFifo.first;
        execMispredictFifo.deq();
        mispredictReg <= tagged Valid mispredict;
    endrule

    rule doMospredict_handle(isValid(mispredictReg));
        //$display("doMispredict_handle");
        let mispredict = fromMaybe(?, mispredictReg);
        mispredictReg <= tagged Invalid;
        if( rob.unenqDone() || rob.isValidRobTag(mispredict.robTag) ) begin
            // Only handle the mispredict if the rob tag is valid
            // TODO: As an optimization, use an invalid rob tag checkpoint
            if( isValid(mispredict.checkpoint) ) begin
                // Tell execution pipelines to kill instructions
                // exec.badBranch( fromMaybe(?, mispredict.checkpoint) );
                alu.badBranch( fromMaybe(?, mispredict.checkpoint) );
                mem.badBranch( fromMaybe(?, mispredict.checkpoint) );

                // Tell the renaming table to revert back to the checkpoint
                rt.restoreCheckpoint( fromMaybe(?, mispredict.checkpoint), mispredict.brBits );

                // Also revert the ras checkpoint
                ras.restoreCheckpoint( fromMaybe(?, mispredict.checkpoint) );

                // Tell the rob to unenqueue all instructions after the branch
                let nextRobTag = (mispredict.robTag == fromInteger(valueOf(RobSize)-1)) ? 0 : mispredict.robTag + 1;
                rob.unenqToCheckpoint( nextRobTag );

                // Tell the decode stage to check against a new epoch
                eEpoch <= nextEpoch(eEpoch);

                // Tell the fetch pipeline to start fetching from the new PC (with an incremented eEpoch)
                fetchRedirectFifo.enq( Redirect{
                                            pc:     mispredict.pc,
                                            nextPc: mispredict.nextPc,
                                            taken:  mispredict.taken,
                                            eEpoch: nextEpoch(eEpoch),
                                            dEpoch: dEpoch } );

                // $display("doMispredict: pc = 0x%h, robTag = 0x%h\n\tnextPc = 0x%h, robTag = 0x%h", mispredict.pc, mispredict.robTag, mispredict.nextPc, nextRobTag);
            end else begin
                // Tell the rob to unenqueue all instructions after the branch
                let nextRobTag = (mispredict.robTag == fromInteger(valueOf(RobSize)-1)) ? 0 : mispredict.robTag + 1;
                rob.unenqStepwiseTo( nextRobTag );

                // Tell the decode stage to check against a new epoch
                eEpoch <= nextEpoch(eEpoch);

                // Tell the fetch pipeline to start fetching from the new PC (with an incremented eEpoch)
                fetchRedirectFifo.enq( Redirect{
                                            pc:     mispredict.pc,
                                            nextPc: mispredict.nextPc,
                                            taken:  mispredict.taken,
                                            eEpoch: nextEpoch(eEpoch),
                                            dEpoch: dEpoch } );

                // $display("doMispredict: [Warning] Redirecting to instruction without checkpoint");
                // $display("\tpc = 0x%h, robTag = 0x%h\n\tnextPc = 0x%h, robTag = 0x%h", mispredict.pc, mispredict.robTag, mispredict.nextPc, nextRobTag);
            end
        end else begin
            let nextRobTag = (mispredict.robTag == fromInteger(valueOf(RobSize)-1)) ? 0 : mispredict.robTag + 1;
            // $display("doMispredict: Ignoring misprediction\n\tpc = 0x%h, robTag = 0x%h\n\tnextPc = 0x%h, robTag = 0x%h", mispredict.pc, mispredict.robTag, mispredict.nextPc, nextRobTag);
        end
    endrule

    rule doRollback;
        $display("doRollback");
        // Begin by getting an instruction from the rob
        let wrongPathInst = rob.last;
        rob.unenq;
        // $display("doRollback: killing pc = 0x%h", wrongPathInst.pc);

        // Correct renaming table and free list
        // Super patern matching
        if( wrongPathInst.dstArchName matches tagged Gpr .arch &&& wrongPathInst.dstOldName matches tagged Valid .phy ) begin
            // $display("\trenaming %d to %d", arch, phy);
            rt.updateTable( arch, phy );
        end
        // Correct checkpoint manager
        if( isValid(wrongPathInst.checkpoint) ) begin
            rt.freeCheckpoint(fromMaybe(?,wrongPathInst.checkpoint));
        end
    endrule

    method ActionValue#( Tuple2#(CopRegIndex, Data) ) cpuToHost;
        let ret <- cop0.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu( Bit#(32) startPC ) if ( !cop0.started );
        cop0.start;
        fetch.startAtPC( startPC );
    endmethod

    method Bool isRunning;
        return cop0.started;
    endmethod

    interface NBCacheClient iCacheClient = toProcMemoryClient( iCache_req, iCache_resp );
    interface NBCacheClient dCacheClient = toProcMemoryClient( dCache_req, dCache_resp );
endmodule

