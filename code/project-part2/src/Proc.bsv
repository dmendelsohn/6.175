import GetPut::*;
import ClientServer::*;
import ProcTypes::*;
import Fifo::*;
import MemUtil::*;
import MemInit::*;
import CacheTypes::*;
import Vector::*;
import Connectable::*;

// Core File
import RegNBCore::*;

// Memory Hierarchy Files
// Instruction Cache
import RegNBICache::*;

// Data Cache -- from part 1 of project
// These files should be put in MemoryHierarchy
import NBCache::*;
import MessageFifo::*;
import MessageRouter::*;
import ParentProtocolProcessor::*;

(* synthesize *)
module mkProc(Proc);
    ///////////
    // Cores //
    ///////////
    Vector#(NumCores, NBCore) cores;
    for( Integer i = 0 ; i < valueOf(NumCores) ; i = i+1 ) begin
        cores[i] <- mkRegNBCore( fromInteger(i) );
    end

    /////////////////
    // Main Memory //
    /////////////////
    Fifo#(2, DDR3_Req)  ddr3ReqFifo     <- mkCFFifo;
    Fifo#(2, DDR3_Resp) ddr3RespFifo    <- mkCFFifo;
    // Module for initializing main memory
    MemInitIfc memInitIfc <- mkMemInitDDR3( ddr3ReqFifo );
    Bool memReady = memInitIfc.done;
    // Creating two top level WideMem interfaces
    // one for instruction caches and one for data caches
    WideMem wideMemWrapper <- mkWideMemFromDDR3( ddr3ReqFifo, ddr3RespFifo );
    Vector#(2, WideMem) topWideMems <- mkSplitWideMem(wideMemWrapper);
    // WideMem interface for instruction caches to use
    WideMem iMemWideMemWrapper = topWideMems[0];
    // WideMem interface for the data caches to use
    WideMem dMemWideMemWrapper = topWideMems[1];

    ////////////////////////
    // Instruction Caches //
    ////////////////////////
    Vector#(NumCores, WideMem) iWideMems <- mkSplitWideMem(iMemWideMemWrapper);
    Vector#(NumCores, NBICacheFull) iCache <- replicateM(mkRegNBICache);
    Vector#(NumCores, Fifo#(4, Addr)) iCache_addr_fifo <- replicateM(mkCFFifo);
    for( Integer i = 0 ; i < valueOf(NumCores) ; i = i+1 ) begin
        // processor to cache connection
        rule procToICache;
            let x <- cores[i].iCacheClient.req;
            iCache[i].req(x);
        endrule
        rule iCacheToProc;
            let x <- iCache[i].resp;
            cores[i].iCacheClient.resp(x);
        endrule
        // cache to widemem connection
        rule issueMemReq;
            Addr a <- iCache[i].memReq;
            iCache_addr_fifo[i].enq(a);
            iWideMems[i].req( WideMemReq{ addr: a, write_en: 0, data: unpack(0) } );
        endrule
        rule getMemResp;
            let a = iCache_addr_fifo[i].first;
            iCache_addr_fifo[i].deq;
            let x <- iWideMems[i].resp;
            iCache[i].memResp(tuple2(a, x));
        endrule
    end

    /////////////////////
    // Message Network //
    /////////////////////

    // construct the necessary number of message FIFOs and connect them with the message router

    Vector#(NumCores, MessageFifo#(MessageFifoSize)) c2r <- replicateM(mkMessageFifo);
    Vector#(NumCores, MessageFifo#(MessageFifoSize)) r2c <- replicateM(mkMessageFifo);
    MessageFifo#(MessageFifoSize) toParent <- mkMessageFifo;
    MessageFifo#(MessageFifoSize) fromParent <- mkMessageFifo;

    Empty dut_router <- mkMessageRouter( c2r, r2c, fromParent, toParent );

    ///////////////////////////////
    // Parent Protocol Processor //
    ///////////////////////////////

    // connect the parent protocol processor to dMemWideMemWrapper
    Empty dut_ppp <- mkParentProtocolProcessor( toParent, fromParent, dMemWideMemWrapper );

    /////////////////
    // Data Caches //
    /////////////////

    // connect each core's dCacheClient to a non-blocking cache using mkConnection
    Vector#(NumCores, NBCache) dCaches;
    for( Integer i = 0 ; i < valueOf(NumCores) ; i = i+1 ) begin
        dCaches[i] <- mkNBCache( fromInteger(i), r2c[i], c2r[i]);
    end

    for( Integer i = 0 ; i < valueOf(NumCores) ; i = i+1 ) begin
        mkConnection(dCaches[i], cores[i].dCacheClient);
    end

    ///////////////////////////
    // CPU to Host debugging //
    ///////////////////////////
    Bool procIsRunning = False;
    for( Integer i = 0 ; i < valueOf(NumCores) ; i = i+1 ) begin
        procIsRunning = procIsRunning || cores[i].isRunning;
    end
    Fifo#(4, Tuple3#(CoreIndex, CopRegIndex, Data)) cpuToHostFifo <- mkCFFifo;
    for( Integer i = 0 ; i < valueOf(NumCores) ; i = i+1 ) begin
        rule fillCpuToHostFifo;
            let x <- cores[i].cpuToHost;
            let y = tuple3( fromInteger(i), tpl_1(x), tpl_2(x) );
            cpuToHostFifo.enq(y);
        endrule
    end

    rule flushDRAM( !procIsRunning );
        ddr3RespFifo.deq;
    endrule

    ///////////////////////
    // Interface methods //
    ///////////////////////
    method ActionValue#(Tuple3#(CoreIndex, CopRegIndex, Data)) cpuToHost;
        let x = cpuToHostFifo.first;
        cpuToHostFifo.deq;
        return x;
    endmethod

    method Action hostToCpu(Tuple2#(Bit#(NumCores), Addr) startcommand) if (memReady);
        let mask = tpl_1(startcommand);
        let addr = tpl_2(startcommand);
        for( Integer i = 0 ; i < valueOf(NumCores) ; i = i+1 ) begin
            if( mask[i] == 1 ) begin
                cores[i].hostToCpu( addr );
            end
        end
    endmethod

    method Bool isRunning;
        return procIsRunning;
    endmethod

    interface MemInitIfc memInit = memInitIfc;

    interface DDR3_Client ddr3client = toGPClient( ddr3ReqFifo, ddr3RespFifo );
endmodule
