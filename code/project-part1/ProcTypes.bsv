/*

Copyright (C) 2012

Arvind <arvind@csail.mit.edu>
Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/


import Types::*;
import FShow::*;
import MemTypes::*;
import Memory::*;
import WideMemInit::*;

interface Proc;
    method ActionValue#(Tuple2#(RIndx, Data)) cpuToHost;
    method Action hostToCpu(Addr startpc);
    interface WideMemInitIfc memInit;
    interface MemoryClient#(24,512) ddr3client;
endinterface

typedef Bit#(5) RIndx;

typedef enum {Unsupported, Alu, Ld, St, J, Jr, Br, Mfc0, Mtc0} IType deriving(Bits, Eq, FShow);
typedef enum {Eq, Neq, Le, Lt, Ge, Gt, AT, NT} BrFunc deriving(Bits, Eq, FShow);
typedef enum {Add, Sub, And, Or, Xor, Nor, Slt, Sltu, LShift, RShift, Sra} AluFunc deriving(Bits, Eq, FShow);

typedef enum {Normal, CopReg} RegType deriving (Bits, Eq, FShow);

typedef void Exception;

typedef struct {
    Addr pc;
    Addr nextPc;
    IType brType;
    Bool taken;
    Bool mispredict;
} Redirect deriving (Bits, Eq, FShow);

typedef struct {
    RegType regType;
    RIndx idx;
} FullIndx deriving (Bits, Eq, FShow);

function Maybe#(FullIndx) validReg(RIndx idx) = Valid (FullIndx{regType: Normal, idx: idx});

function Maybe#(FullIndx) validCop(RIndx idx) = Valid (FullIndx{regType: CopReg, idx: idx});

function RIndx validRegValue(Maybe#(FullIndx) idx) = validValue(idx).idx;

typedef struct {
    IType            iType;
    AluFunc          aluFunc;
    BrFunc           brFunc;
    Maybe#(FullIndx) dst;
    Maybe#(FullIndx) src1;
    Maybe#(FullIndx) src2;
    Maybe#(Data)     imm;
} DecodedInst deriving(Bits, Eq, FShow);

typedef struct {
    IType            iType;
    Maybe#(FullIndx) dst;
    Data             data;
    Addr             addr;
    Bool             mispredict;
    Bool             brTaken;
} ExecInst deriving(Bits, Eq, FShow);

Bit#(6) opFUNC  = 6'b000000;
Bit#(6) opRT    = 6'b000001;
Bit#(6) opRS    = 6'b010000;
                            
Bit#(6) opLB    = 6'b100000;
Bit#(6) opLH    = 6'b100001;
Bit#(6) opLW    = 6'b100011;
Bit#(6) opLBU   = 6'b100100;
Bit#(6) opLHU   = 6'b100101;
Bit#(6) opSB    = 6'b101000;
Bit#(6) opSH    = 6'b101001;
Bit#(6) opSW    = 6'b101011;
                            
Bit#(6) opADDIU = 6'b001001;
Bit#(6) opSLTI  = 6'b001010;
Bit#(6) opSLTIU = 6'b001011;
Bit#(6) opANDI  = 6'b001100;
Bit#(6) opORI   = 6'b001101;
Bit#(6) opXORI  = 6'b001110;
Bit#(6) opLUI   = 6'b001111;
                            
Bit#(6) opJ     = 6'b000010;
Bit#(6) opJAL   = 6'b000011;
Bit#(6) fcJR    = 6'b001000;
Bit#(6) fcJALR  = 6'b001001;
Bit#(6) opBEQ   = 6'b000100;
Bit#(6) opBNE   = 6'b000101;
Bit#(6) opBLEZ  = 6'b000110;
Bit#(6) opBGTZ  = 6'b000111;
Bit#(5) rtBLTZ  = 5'b00000;
Bit#(5) rtBGEZ  = 5'b00001;

Bit#(5) rsMFC0  = 5'b00000;
Bit#(5) rsMTC0  = 5'b00100;
Bit#(5) rsERET  = 5'b10000;

Bit#(6) fcSLL   = 6'b000000;
Bit#(6) fcSRL   = 6'b000010;
Bit#(6) fcSRA   = 6'b000011;
Bit#(6) fcSLLV  = 6'b000100;
Bit#(6) fcSRLV  = 6'b000110;
Bit#(6) fcSRAV  = 6'b000111;
Bit#(6) fcADDU  = 6'b100001;
Bit#(6) fcSUBU  = 6'b100011;
Bit#(6) fcAND   = 6'b100100;
Bit#(6) fcOR    = 6'b100101;
Bit#(6) fcXOR   = 6'b100110;
Bit#(6) fcNOR   = 6'b100111;
Bit#(6) fcSLT   = 6'b101010;
Bit#(6) fcSLTU  = 6'b101011;
Bit#(6) fcMULT  = 6'b011000;

function Bool dataHazard(Maybe#(RIndx) src1, Maybe#(RIndx) src2, Maybe#(RIndx) dst);
    return (isValid(dst) && ((isValid(src1) && validValue(dst)==validValue(src1)) ||
                             (isValid(src2) && validValue(dst)==validValue(src2))));
endfunction

function Fmt showInst(Data inst);
    Fmt ret = $format("");
    let opcode = inst[ 31 : 26 ];
    let rs     = inst[ 25 : 21 ];
    let rt     = inst[ 20 : 16 ];
    let rd     = inst[ 15 : 11 ];
    let shamt  = inst[ 10 :  6 ];
    let funct  = inst[  5 :  0 ];
    let imm    = inst[ 15 :  0 ];
    let target = inst[ 25 :  0 ];

    case (opcode)
        opADDIU, opSLTI, opSLTIU, opANDI, opORI, opXORI, opLUI:
        begin
            ret = case (opcode)
                        opADDIU: $format("addiu");
                        opLUI:   $format("lui");
                        opSLTI:  $format("slti");
                        opSLTIU: $format("sltiu");
                        opANDI:  $format("andi");
                        opORI:   $format("ori");
                        opXORI:  $format("xori");
                    endcase;
            ret = ret + $format(" r%0d = r%0d ", rt, rs);
            ret = ret + (case (opcode)
                            opADDIU, opSLTI, opSLTIU: $format("0x%0x", imm);
                            opLUI: $format("0x%0x", {imm, 16'b0});
                            default: $format("0x%0x", imm);
                        endcase);
        end

        opLB, opLH, opLW, opLBU, opLHU:
        begin
            ret = case (opcode)
                        opLB:  $format("lb");
                        opLH:  $format("lh");
                        opLW:  $format("lw");
                        opLBU: $format("lbu");
                        opLHU: $format("lhu");
                    endcase;
            ret = ret + $format(" r%0d = r%0d 0x%0x", rt, rs, imm);
        end

        opSB, opSH, opSW:
        begin
            ret = case (opcode)
                        opSB: $format("sb");
                        opSH: $format("sh");
                        opSW: $format("sw");
                    endcase;
            ret = ret + $format(" r%0d r%0d 0x%0x", rs, rt, imm);
        end

        opJ, opJAL: ret = (opcode == opJ? $format("j ") : $format("jal ")) + $format("0x%0x", {target, 2'b00});
    
        opBEQ, opBNE, opBLEZ, opBGTZ, opRT:
        begin
            ret = case(opcode)
                        opBEQ:  $format("beq");
                        opBNE:  $format("bne");
                        opBLEZ: $format("blez");
                        opBGTZ: $format("bgtz");
                        opRT: (rt==rtBLTZ ? $format("bltz") : $format("bgez"));
                    endcase;
            ret = ret + $format(" r%0d ", rs) + ((opcode == opBEQ || opcode == opBNE)? $format("r%0d", rt) : $format("0x%0x", imm));
        end
    
        opRS: 
        begin
            case (rs)
                rsMFC0: ret = $format("mfc0 r%0d = [r%0d]", rt, rd);
                rsMTC0: ret = $format("mtc0 [r%0d] = r%0d", rd, rt);
            endcase
        end
    
        opFUNC:
        case(funct)
            fcJR, fcJALR:   ret = (funct == fcJR ? $format("jr") : $format("jalr")) + $format(" r%0d = r%0d", rd, rs);
            fcSLL, fcSRL, fcSRA:
            begin
                ret = case (funct)
                            fcSLL: $format("sll");
                            fcSRL: $format("srl");
                            fcSRA: $format("sra");
                        endcase;
                ret = ret + $format(" r%0d = r%0d ", rd, rt) + ((funct == fcSRA) ? $format(">>") : $format("<<")) + $format(" %0d", shamt);
            end
            fcSLLV, fcSRLV, fcSRAV: 
            begin
                ret = case (funct)
                            fcSLLV: $format("sllv");
                            fcSRLV: $format("srlv");
                            fcSRAV: $format("srav");
                        endcase;
                ret = ret + $format(" r%0d = r%0d r%0d", rd, rt, rs);
            end
            default: 
            begin
                ret = case (funct)
                            fcADDU: $format("addu");
                            fcSUBU: $format("subu");
                            fcAND : $format("and");
                            fcOR  : $format("or");
                            fcXOR : $format("xor");
                            fcNOR : $format("nor");
                            fcSLT : $format("slt");
                            fcSLTU: $format("sltu");
                        endcase;
                ret = ret + $format(" r%0d = r%0d r%0d", rd, rs, rt);
            end
        endcase

        default: ret = $format("nop 0x%0x", inst);
    endcase

    return ret;
  
endfunction
