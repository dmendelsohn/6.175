import GetPut::*;
import BRAM::*;
import RegFile::*;
import Vector::*;
import Memory::*;
import Fifo::*;

import ProcTypes::*;
import MemUtil::*;

module mkMemInitRegFile(RegFile#(Bit#(16), Data) mem, MemInitIfc ifc);
    Reg#(Bool) initialized <- mkReg(False);

    interface Put request;
        method Action put(MemInit x) if (!initialized);
          case (x) matches
            tagged InitLoad .l: begin
                mem.upd(truncate(l.addr), l.data);
            end

            tagged InitDone: begin
                initialized <= True;
            end
          endcase
        endmethod
    endinterface

    method Bool done() = initialized;

endmodule

module mkMemInitBRAM(BRAM1Port#(Bit#(16), Data) mem, MemInitIfc ifc);
    Reg#(Bool) initialized <- mkReg(False);

    interface Put request;
        method Action put(MemInit x) if (!initialized);
          case (x) matches
            tagged InitLoad .l: begin
                mem.portA.request.put(BRAMRequest {
                    write: True,
                    responseOnWrite: False,
                    address: truncate(l.addr),
                    datain: l.data});
            end

            tagged InitDone: begin
                initialized <= True;
            end
          endcase
        endmethod
    endinterface

    method Bool done() = initialized;

endmodule

module mkMemInitFPGAMemory(FPGAMemory mem, MemInitIfc ifc);
    Reg#(Bool) initialized <- mkReg(False);

    interface Put request;
        method Action put(MemInit x) if (!initialized);
          case (x) matches
            tagged InitLoad .l: begin
                mem.req(MemReq {
                    op: St,
                    addr: {0,(l.addr << 2)},
                    data: l.data});
            end

            tagged InitDone: begin
                initialized <= True;
            end
          endcase
        endmethod
    endinterface

    method Bool done() = initialized;

endmodule

module mkMemInitDDR3( Fifo#(n,DDR3_Req) reqQ, MemInitIfc ifc );
    // logic to initialize DRAM
    Reg#(Bool) initialized <- mkReg(False);

    interface Put request;
        method Action put(MemInit x) if (!initialized);
          case (x) matches
            tagged InitLoad .l: begin
                MemReq r = MemReq{ op:St, addr:(l.addr << 2), data:l.data };
                DDR3_Req ddr3_req = toDDR3Req(r);
                reqQ.enq( ddr3_req );
                // $display( "mkMemInitDDR3::put : l.addr = 0x%0x, ddr3_req.address = 0x%0x, ddr3_req.byteen = 0x%0x", l.addr, ddr3_req.address, ddr3_req.byteen );
            end
            tagged InitDone: begin
                initialized <= True;
            end
          endcase
        endmethod
    endinterface
    method Bool done() = initialized;
endmodule

