// Execute pipeline
import ProcTypes::*;

import Vector::*;
import Fifo::*;
import BBFifo::*;

import TypeClasses::*;

import Exec::*;
import RFile::*;
import RegOoOCompletionBuffer::*;

interface NBMemoryPipeline;
    method Action badBranch( CheckpointTag tag );
    method Action goodBranch( CheckpointTag tag );
endinterface

module mkRegNBMemoryPipeline(   BBFifo#(2, MemIssuedInst)   toMemFifo,
                                BBFifo#(2, MemRespInst)     fromMemFifo,
                                Cop                         cop0,
                                NBCache                     nbcache,
                                RFile                       rf,
                                NBMemoryPipeline ifc);
    OoOCompletionBuffer#(NBCacheSize) ooo_buffer <- mkRegOoOCompletionBuffer;

    rule doRegFetch(cop0.started);
        MemIssuedInst mInst = toMemFifo.first;
        toMemFifo.deq;

         $display("NBMemoryPipeline : pc = %h, iType = ", mInst.pc, fshow(mInst.iType));

        MemReqInst reqInst = toMemReqInst(mInst);
        // reqInst is missing addr and data

        // Register Read
        Data rVal1 = rf.rd1( getGpr(mInst.src1) );
        Data rVal2 = rf.rd2( getGpr(mInst.src2) );

        // For iType == St and Sc
        reqInst.data = rVal2;

        if( !isValid(mInst.imm) ) begin
            $fwrite(stderr, "ERROR: NBMemoryPipeline : immediate field of incoming instruction is not valid");
            $finish;
        end else begin
            reqInst.addr = rVal1 + fromMaybe(?, mInst.imm);
        end

        // Send to non-blocking cache and OoO Completion Buffer (only for ld, ll, or sc)
        NBCacheToken buffer_tag = 0;
        if( reqInst.op == Ld || reqInst.op == Ll || reqInst.op == Sc ) begin
            buffer_tag <- ooo_buffer.insert(reqInst);
        end
        nbcache.req( NBCacheReq{ addr: reqInst.addr, data: reqInst.data, op: reqInst.op, token: buffer_tag } );
    endrule


    rule doMemResp(cop0.started);
        //$display("doMemResp");
        // resp will be a ld, ll, or sc response by construction
        let nbresp <- nbcache.resp();
        Maybe#(MemRespInst) mresp <- ooo_buffer.remove(nbresp.token, nbresp.data);

        if( isValid(mresp) ) begin
            let resp = fromMaybe(?, mresp);
            // update register file
            case(resp.dst) matches
                tagged Gpr .x: rf.wr( x, resp.data );
                tagged Cop0 .x: cop0.wr( x, resp.data );
            endcase
            // send to ROB
            fromMemFifo.enq(resp);
        end
    endrule


   	method Action badBranch( CheckpointTag tag );
        // $display("MemoryPipeline: badBranch, tag = 0x%0x", tag);
        toMemFifo.badBranch( tag );
        ooo_buffer.badBranch( tag );
        fromMemFifo.badBranch( tag );
    endmethod

    method Action goodBranch( CheckpointTag tag );
        // $display("MemoryPipeline: goodBranch, tag = 0x%0x", tag);
        toMemFifo.goodBranch( tag );
        ooo_buffer.goodBranch( tag );
        fromMemFifo.goodBranch( tag );
    endmethod
endmodule


