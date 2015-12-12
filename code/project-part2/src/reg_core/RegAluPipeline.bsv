import ProcTypes::*;

import Vector::*;
import BBFifo::*;
import RegBBFifo::*;

import TypeClasses::*;

import Exec::*;
import RFile::*;

interface AluPipeline;
    method Action badBranch( CheckpointTag tag );
    method Action goodBranch( CheckpointTag tag );
endinterface

module mkRegAluPipeline(    BBFifo#(2, IssuedInst)      toAluFifo,
                            BBFifo#(2, ExecutedInst)    fromAluFifo,
                            BBFifo#(2, Mispredict)      mispredictFifo,
                            Cop                         cop0,
                            RFile                       rf,
                            AluPipeline ifc);
    BBFifo#(2, IssuedInstWithData)  rf2eFifo    <- mkRegBBFifo;
    BBFifo#(2, ExecutedInst)        e2rfwFifo   <- mkRegBBFifo;

    rule doRegFetch(cop0.started);
        // get renamed inst from toAluFifo
        let rInst = toAluFifo.first;
        toAluFifo.deq;

        IssuedInstWithData dInst = toIssuedInstWithData(rInst);

        // Register Read
        dInst.rVal1 = rf.rd1( getGpr(rInst.src1) );
        dInst.rVal2 = rf.rd2( getGpr(rInst.src2) );
        dInst.copVal = cop0.rd( getCop0(rInst.src1) );

        //$display("doRegFetch: pc = 0x%h", dInst.pc);
        // if( isCop0(rInst.src1) ) begin
        //     $display("\tsrc1 = ", fshow(rInst.src1), ", dInst.copVal = 0x%h", dInst.copVal);
        // end else begin
        //     $display("\tsrc1 = ", fshow(rInst.src1), ", dInst.rVal1 = 0x%h", dInst.rVal1);
        // end
        // $display("\tsrc2 = ", fshow(rInst.src2), ", dInst.rVal2 = 0x%h", dInst.rVal2);

        // Enqueue data into register fetch to execute fifo and update state
        rf2eFifo.enq( dInst );
    endrule

    rule doExecute(cop0.started);
        // Unpack data from register fetch to execute fifo
        let dInst = rf2eFifo.first;
        rf2eFifo.deq;

        if(dInst.iType == Unsupported) begin
            $fwrite(stderr, "Executing unsupported instruction at pc: %x. Exiting\n", dInst.pc);
            $finish;
        end

        // Execute
        ExecutedInst eInst = exec(dInst);

         //$display("doExecute: pc = 0x%h", dInst.pc);
        // $display("\teInst.Data = 0x%h", eInst.data);
        // $display("\teInst.dst = ", fshow(eInst.dst));
        // $display("\tBranchBits = 0b%b", eInst.brBits);

        if( eInst.mispredict ) begin
            // Handle misprediction
            // $display("\tMisprediction!");
            // $display("\tCheckpoint = %0d", (isValid(eInst.checkpoint) ? fromMaybe(?,eInst.checkpoint) : -1));
            mispredictFifo.enq( Mispredict{pc:dInst.pc, nextPc:eInst.addr, brType:eInst.iType, taken:eInst.brTaken, mispredict:eInst.mispredict, brBits: eInst.brBits, checkpoint: eInst.checkpoint, robTag: eInst.robTag} );
        end

        e2rfwFifo.enq( eInst );
    endrule

    rule doRFWrite(cop0.started);
        let eInst = e2rfwFifo.first;
        e2rfwFifo.deq;

         //$display("doRFWrite: pc = 0x%h", eInst.pc);

        // Write Back
        case( eInst.dst ) matches
            tagged Gpr  .r : rf.wr( r, eInst.data );
            tagged Cop0 .r : cop0.wr( r, eInst.data );
        endcase

        fromAluFifo.enq(eInst);
    endrule

    method Action badBranch( CheckpointTag tag );
        // $display("AluPipeline: badBranch, tag = 0x%h", tag);
        toAluFifo.badBranch(       tag );
        rf2eFifo.badBranch(         tag );
        e2rfwFifo.badBranch(       tag );
        fromAluFifo.badBranch(     tag );
        mispredictFifo.badBranch(   tag );
    endmethod

    method Action goodBranch( CheckpointTag tag );
        // $display("AluPipeline: goodBranch, tag = 0x%h", tag);
        toAluFifo.goodBranch(      tag );
        rf2eFifo.goodBranch(        tag );
        e2rfwFifo.goodBranch(      tag );
        fromAluFifo.goodBranch(    tag );
        mispredictFifo.goodBranch(  tag );
    endmethod
endmodule


