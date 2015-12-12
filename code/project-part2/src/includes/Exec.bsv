/*

Copyright (C) 2012

Arvind <arvind@csail.mit.edu>
Derek Chiou <derek@ece.utexas.edu>
Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import ProcTypes::*;
import Vector::*;

(* noinline *)
function Data alu(Data a, Data b, AluFunc func);
  Data res = case(func)
     Add   : (a + b);
     Sub   : (a - b);
     And   : (a & b);
     Or    : (a | b);
     Xor   : (a ^ b);
     Nor   : ~(a | b);
     Slt   : zeroExtend( pack( signedLT(a, b) ) );
     Sltu  : zeroExtend( pack( a < b ) );
     LShift: (a << b[4:0]);
     RShift: (a >> b[4:0]);
     Sra   : signedShiftRight(a, b[4:0]);
  endcase;
  return res;
endfunction

(* noinline *)
function Bool aluBr(Data a, Data b, BrFunc brFunc);
  Bool brTaken = case(brFunc)
    Eq  : (a == b);
    Neq : (a != b);
    Le  : signedLE(a, 0);
    Lt  : signedLT(a, 0);
    Ge  : signedGE(a, 0);
    Gt  : signedGT(a, 0);
    AT  : True;
    NT  : False;
  endcase;
  return brTaken;
endfunction

(* noinline *)
function Addr brAddrCalc(Addr pc, Data val, IType iType, Data imm, Bool taken);
  Addr pcPlus4 = pc + 4; 
  Addr targetAddr = case (iType)
    J  : {pcPlus4[31:28], imm[27:0]};
    Jr : val;
    Br : (taken? pcPlus4 + imm : pcPlus4);
    Alu, Ld, St, Ll, Sc, Mfc0, Mtc0, Unsupported: pcPlus4;
  endcase;
  return targetAddr;
endfunction

(* noinline *)
function ExecutedInst exec(IssuedInstWithData dInst);
  // Pass all shared fields from InstWithData to ExecInst
  ExecutedInst eInst = toExecutedInst(dInst);

  Data aluVal2 = isValid(dInst.imm) ? validValue(dInst.imm) : dInst.rVal2;
  
  let aluRes = alu(dInst.rVal1, aluVal2, dInst.aluFunc);
  
  eInst.iType = dInst.iType;
  
  eInst.data = dInst.iType == Mfc0?
                 dInst.copVal :
               dInst.iType == Mtc0?
                 dInst.rVal1 :
               (dInst.iType==St || dInst.iType==Sc) ?
                 dInst.rVal2 :
               (dInst.iType==J || dInst.iType==Jr) ?
                 (dInst.pc+4) :
                 aluRes;
  
  let brTaken = aluBr(dInst.rVal1, dInst.rVal2, dInst.brFunc);
  let brAddr = brAddrCalc(dInst.pc, dInst.rVal1, dInst.iType, validValue(dInst.imm), brTaken);
  eInst.mispredict = brAddr != dInst.ppc;

  eInst.brTaken = brTaken;
  eInst.addr = (dInst.iType == Ld || dInst.iType == St || dInst.iType == Ll || dInst.iType == Sc) ? aluRes : brAddr;
  
  eInst.dst = dInst.dst;

  return eInst;
endfunction
