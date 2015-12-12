/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import ProcTypes::*;
import Fifo::*;
import RegFifo::*;

(* synthesize *)
module mkRegCop(CoreIndex coreid, Cop ifc);
  Reg#(Bool) startReg   <- mkReg(False);
  Reg#(Data) numInsts   <- mkReg(0);
  Reg#(Data) timeReg    <- mkReg(?);
  Reg#(Bool) finishReg  <- mkReg(False);
  Reg#(Data) finishCode <- mkReg(0);
  Data coreID = zeroExtend(coreid);

  Fifo#(2, Tuple2#(CopRegIndex, Data)) copFifo <- mkRegFifo;

  Reg#(Data) cycles <- mkReg(0);

  rule count (startReg);
     cycles <= cycles + 1;
     $display("\nCycle %d ----------------------------------------------------", cycles);
  endrule

  method Action start;
    startReg <= True;
    cycles <= 0;
  endmethod

  method Bool started;
    return startReg;
  endmethod

  method Data rd(CopRegIndex idx);
    return (case(idx)
      10: cycles;
      11: numInsts;
      15: coreID;
      21: finishCode;
    endcase);
  endmethod

  /*
    Register 10: (Read only) current time
    Register 11: (Read only) returns current number of instructions
    Register 18: (Write only) Write an integer to stderr
    Register 19: (Write only) Write a char to stderr
    Register 21: Finish code
    Register 22: (Write only) Finished executing
  */
  method Action wr(CopRegIndex idx, Data val);
    case (idx)
      18: copFifo.enq(tuple2(18, val));
      19: copFifo.enq(tuple2(19, val));
      21: copFifo.enq(tuple2(21, val));
    endcase
    if( idx == 21 ) begin
      startReg <= False;
    end
  endmethod

  method Action commitInst;
    numInsts <= numInsts + 1;
  endmethod

  method ActionValue#(Tuple2#(CopRegIndex, Data)) cpuToHost;
    copFifo.deq;
    return copFifo.first;
  endmethod
endmodule
