import ProcTypes::*;
import Fifo::*;
import RegFifo::*;
import MemInit::*;
import RegAddrPred::*;

interface FetchPipeline;
    method Action startAtPC(Addr startPC);
    method Action stop;
endinterface

module mkRegNBFetchPipeline(
        Fifo#(2, FetchedInst) fromInstFetchFifo,
        Fifo#(2, Redirect)    redirectFifo,
        NBICache              iCache,
        FetchPipeline ifc );
    Reg#(Bool) running <- mkReg(False);
    Reg#(Addr)      pc <- mkReg(0);
    AddrPred       btb <- mkRegBtb;

    Reg#(DecodeEpoch)  dEpoch <- mkReg(0);
    Reg#(ExecuteEpoch) eEpoch <- mkReg(0);

    Fifo#(4, FetchedInst) fetchWaitFifo <- mkRegFifo();

    rule doInstFetch1( running );
        //$display("doInstFetch1");
        if( redirectFifo.notEmpty ) begin
            // everything in redirectFifo is always valid (how nice!)
            let redir = redirectFifo.first;
            redirectFifo.deq;

            // Always update btb (even though it may be speculative)
            btb.update(redir);

            dEpoch <= redir.dEpoch;
            eEpoch <= redir.eEpoch;

            // Lets redirect
            pc <= redir.nextPc;
            // $display("InstFetch: PC redirecting to 0x%h", redir.nextPc);
        end else begin
            // Fetch
            iCache.req(pc);
            Addr ppc = btb.predPc(pc);
            fetchWaitFifo.enq( FetchedInst{pc:pc, ppc:ppc, inst:0, dEpoch:dEpoch, eEpoch:eEpoch} );
            pc <= ppc;
            // $display("InstFetch: Fetching pc = 0x%h", pc);
        end
    endrule

    // rule doInstFetchKill( running && (fetchWaitFifo.first.dEpoch != dEpoch || fetchWaitFifo.first.eEpoch != eEpoch) );
    //     $display("InstFetchKill: Wrong path instruction");
    //     fetchWaitFifo.deq();
    //     iCache.kill();
    // endrule

    rule doInstFetch2( running );
        //$display("doInstFetch2");
        let fInst = fetchWaitFifo.first;
        fetchWaitFifo.deq;

        // Get the response from the memory
        fInst.inst <- iCache.resp;

        if( fetchWaitFifo.first.dEpoch == dEpoch && fetchWaitFifo.first.eEpoch == eEpoch ) begin
            // The guards ensure that the epochs match
            // $display("InstFetch2: Fetched pc = 0x%h\n\t", fInst.pc, showInst(fInst.inst));
            fromInstFetchFifo.enq( fInst );
        end else begin
            // $display("InstFetch2: Dropping wrong path instruction");
        end
    endrule

    method Action startAtPC(Addr startPC);
        running <= True;
        pc <= startPC;
    endmethod

    method Action stop();
        running <= False;
    endmethod

endmodule
