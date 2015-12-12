import FShow::*;
import Memory::*;
import GetPut::*;
import Vector::*;
import Connectable::*;
import Fifo::*;

typedef 32 AddrSize;
typedef Bit#(AddrSize) Addr;

typedef 32 DataSize;
typedef Bit#(DataSize) Data;

//------------------
// Generic Mem Type
//------------------

interface ProcMemory#( type req_type, type resp_type );
    method Action req( req_type req );
    method ActionValue#( resp_type ) resp;
endinterface

// something that uses a ProcMemory#(req_type,resp_type)
interface ProcMemoryClient#( type req_type, type resp_type );
    method ActionValue#(req_type) req;
    method Action resp( resp_type resp );
endinterface

instance Connectable#(ProcMemory#(req_type, resp_type), ProcMemoryClient#(req_type, resp_type)) provisos(Bits#(req_type,a__), Bits#(resp_type,b__));
    module mkConnection( ProcMemory#(req_type, resp_type) memServer, ProcMemoryClient#(req_type, resp_type) memClient, Empty ifc );
        rule connect_resp;
            let x <- memServer.resp;
            memClient.resp(x);
        endrule
        rule connect_req;
            let x <- memClient.req();
            memServer.req(x);
        endrule
    endmodule
endinstance

instance Connectable#(ProcMemoryClient#(req_type, resp_type), ProcMemory#(req_type, resp_type)) provisos(Bits#(req_type,a__), Bits#(resp_type,b__));
    module mkConnection( ProcMemoryClient#(req_type, resp_type) memClient, ProcMemory#(req_type, resp_type) memServer, Empty ifc );
        rule connect_resp;
            let x <- memServer.resp;
            memClient.resp(x);
        endrule
        rule connect_req;
            let x <- memClient.req();
            memServer.req(x);
        endrule
    endmodule
endinstance

function ProcMemory#(req_type, resp_type) toProcMemory( Fifo#(n, req_type) req_fifo, Fifo#(m, resp_type) resp_fifo );
    return (interface ProcMemory;
                method Action req(req_type x);
                    req_fifo.enq(x);
                endmethod
                method ActionValue#(resp_type) resp;
                    let x = resp_fifo.first;
                    resp_fifo.deq;
                    return x;
                endmethod
            endinterface);
endfunction

function ProcMemoryClient#(req_type, resp_type) toProcMemoryClient( Fifo#(n, req_type) req_fifo, Fifo#(m, resp_type) resp_fifo );
    return (interface ProcMemoryClient;
                method ActionValue#(req_type) req;
                    let x = req_fifo.first;
                    req_fifo.deq;
                    return x;
                endmethod
                method Action resp(resp_type x);
                    resp_fifo.enq(x);
                endmethod
            endinterface);
endfunction

//------------
// DDR3 Types
//------------

typedef 24 DDR3AddrSize;
typedef Bit#(DDR3AddrSize) DDR3Addr;
typedef 512 DDR3DataSize;
typedef Bit#(DDR3DataSize) DDR3Data;
typedef TDiv#(DDR3DataSize, 8) DDR3DataBytes;
typedef Bit#(DDR3DataBytes) DDR3ByteEn;
typedef TDiv#(DDR3DataSize, DataSize) DDR3DataWords;

// typedef struct {
//     Bool        write;
//     Bit#(64)    byteen;
//     Bit#(24)    address;
//     Bit#(512)   data;
// } DDR3_Req deriving (Bits, Eq);
typedef MemoryRequest#(DDR3AddrSize, DDR3DataSize) DDR3_Req;

// typedef struct {
//     Bit#(512)   data;
// } DDR3_Resp deriving (Bits, Eq);
typedef MemoryResponse#(DDR3DataSize) DDR3_Resp;

// interface DDR3_Client;
//     interface Get#( DDR3_Req )  request;
//     interface Put#( DDR3_Resp ) response;
// endinterface;
typedef MemoryClient#(DDR3AddrSize, DDR3DataSize) DDR3_Client;

//-------------
// Cache Types
//-------------

typedef DDR3DataSize CacheLineSize;
typedef TDiv#(CacheLineSize, 8) CacheLineBytes;
typedef TDiv#(CacheLineSize, DataSize) CacheLineWords;
typedef Vector#(CacheLineWords, Data) CacheLine;
typedef Bit#(TLog#(CacheLineWords)) CacheWordSelect;
typedef Bit#(TLog#(CacheLineWords)) CacheOffset; // another name for word select
typedef TLog#(CacheRows) CacheIndexSz;
typedef TSub#(TSub#(30,TLog#(CacheRows)),TLog#(CacheLineWords)) CacheTagSz;

typedef 16 CacheRows;

typedef Bit#( TSub#(TSub#(30,TLog#(CacheRows)),TLog#(CacheLineWords)) ) CacheTag;
typedef Bit#( TLog#(CacheRows) ) CacheIndex;

//---------------
// WideMem Types
//---------------

typedef struct {
    Bit#(CacheLineWords)    write_en;   // Word Write En
    Addr                    addr;       // SMIPS Address (Byte Addressed)
    CacheLine               data;       // Data to write
} WideMemReq deriving(Eq, Bits, FShow);
typedef CacheLine WideMemResp;

typedef ProcMemory#(WideMemReq, WideMemResp) WideMem;

//------------------
// Normal Mem Types
//------------------

typedef enum{Ld, St, Ll, Sc} MemOp deriving(Eq, Bits, FShow);
typedef struct{
    MemOp   op;
    Addr    addr;
    Data    data;
} MemReq deriving(Eq, Bits, FShow);
typedef Data MemResp;

typedef ProcMemory#(MemReq, MemResp) Cache;
typedef ProcMemoryClient#(MemReq, MemResp) CacheClient;
typedef ProcMemory#(MemReq, MemResp) DCache;
typedef ProcMemory#(Addr, Data) ICache;
typedef ProcMemory#(MemReq, MemResp) FPGAMemory;

function MemOp toMemOp( IType x );
    case (x)
        Ll: return Ll;
        Ld: return Ld;
        Sc: return Sc;
        St: return St;
        default: return ?;
    endcase
endfunction

//------------------------
// Non-Blocking Mem Types
//------------------------
typedef 8 NBCacheSize;
typedef 4 StQSz;
typedef 4 LdBuffSz;

typedef Bit#(TLog#(NBCacheSize)) NBCacheToken;
typedef struct {
    Addr            addr;
    Data            data;
    MemOp           op;     // ld, ll, st, sc
    NBCacheToken    token;  // ld, ll, sc
} NBCacheReq deriving(Bits, Eq, FShow);
typedef struct {
    Data            data;
    NBCacheToken    token;
} NBCacheResp deriving(Bits, Eq, FShow);
typedef ProcMemory#(NBCacheReq, NBCacheResp) NBCache;
typedef ProcMemory#(Addr, Data) NBICache;

//---------------
// MemInit Types
//---------------

typedef struct {
    Addr addr;
    Data data;
} MemInitLoad deriving(Eq, Bits, FShow);

typedef union tagged {
   MemInitLoad InitLoad;
   void InitDone;
} MemInit deriving(Eq, Bits, FShow);

interface MemInitIfc;
  interface Put#(MemInit) request;
  method Bool done();
endinterface

//------------
// Proc Type
//------------

interface Proc;
    method ActionValue#(Tuple3#(CoreIndex, CopRegIndex, Data)) cpuToHost;
    method Action hostToCpu(Tuple2#(Bit#(NumCores), Addr) startcommand);
    method Bool isRunning;
    interface MemInitIfc memInit;
    interface MemoryClient#(24,512) ddr3client;
endinterface

typedef 2 NumCores;
typedef Bit#(TLog#(NumCores)) CoreIndex;

interface Core#(type i_req_t, type i_resp_t, type d_req_t, type d_resp_t);
    method ActionValue#(Tuple2#(CopRegIndex, Data)) cpuToHost;
    method Action hostToCpu(Addr startpc);
    interface ProcMemoryClient#(i_req_t, i_resp_t) iCacheClient;
    interface ProcMemoryClient#(d_req_t, d_resp_t) dCacheClient;
    method Bool isRunning;
endinterface

typedef Core#(MemReq, MemResp, MemReq, MemResp) BlockingCore;
typedef Core#(Addr, Data, NBCacheReq, NBCacheResp) NBCore;

//-------------------
// Coprocessor Types
//-------------------

interface Cop;
  method Action start;
  method Bool started;
  method Data rd(CopRegIndex idx);
  method Action wr(CopRegIndex idx, Data val);
  method Action commitInst;

  method ActionValue#(Tuple2#(CopRegIndex, Data)) cpuToHost;
endinterface

//--------------------
// Out of Order Types
//--------------------

// XXX Temporary smaller size
// typedef 4 NumCheckpoint;
typedef 2 NumCheckpoint;
// 1 checkpoint causes an error due to type class instances
typedef Bit#(TLog#(NumCheckpoint)) CheckpointTag;

// typedef 64 NumPhyReg;
// XXX Temporary smaller size
typedef 40 NumPhyReg; // 8 element rob
typedef Bit#(TLog#(NumPhyReg)) PhyRegIndex;

typedef 32 NumArchReg;
typedef Bit#(TLog#(NumArchReg)) ArchRegIndex;

typedef 32 NumCopReg;
typedef Bit#(TLog#(NumCopReg)) CopRegIndex;

typedef TSub#(NumPhyReg,NumArchReg) RobSize;
typedef Bit#(TLog#(RobSize)) RobIndex;
typedef RobSize FreeListSize;

typedef enum {Unsupported, Alu, Ld, St, Ll, Sc, J, Jr, Br, Mfc0, Mtc0} IType deriving(Bits, Eq, FShow);
typedef enum {Eq, Neq, Le, Lt, Ge, Gt, AT, NT} BrFunc deriving(Bits, Eq, FShow);
typedef enum {Add, Sub, And, Or, Xor, Nor, Slt, Sltu, LShift, RShift, Sra} AluFunc deriving(Bits, Eq, FShow);

typedef void Exception;

typedef struct {
    Addr                    pc;
    Addr                    nextPc;
    IType                   brType;
    Bool                    taken;
    Bool                    mispredict;
    Maybe#(CheckpointTag)   checkpoint;
    Bit#(NumCheckpoint)     brBits;
    RobIndex                robTag;
} Mispredict deriving (Bits, Eq, FShow);

typedef struct {
    Addr            pc;     // pc of instruction causing redirect
    Addr            nextPc; // address to redirect pc to
    Bool            taken;  // true if nextPc != pc + 4
    ExecuteEpoch    eEpoch;
    DecodeEpoch     dEpoch;
} Redirect deriving (Bits, Eq, FShow);

typedef struct {
    Addr            pc;
    Addr            nextPc;
    IType           brType;
    Bool            taken;
} Training deriving (Bits, Eq, FShow);

// These two tagged unions are instances of the typeclass RegIndexType#()

typedef union tagged {
    gprIndex        Gpr;
    CopRegIndex     Cop0;
    void            Invalid;
} FullRegIndex#(type gprIndex)  deriving (Bits, Eq); // FShow is custom

typedef FullRegIndex#(ArchRegIndex) FullArchRegIndex;
typedef FullRegIndex#(PhyRegIndex) FullPhyRegIndex;

instance FShow#( FullRegIndex#(t) ) provisos (FShow#(t), Bits#(t, a__));
    function Fmt fshow( FullRegIndex#(t) x );
        case (x) matches
                tagged Gpr .r  : return $format("Gpr %0d", r);
                tagged Cop0 .r : return $format("Cop0 %0d", r);
                tagged Invalid : return $format("Invalid");
            endcase
    endfunction
endinstance

// Epoch type needed for instruction fetch and decode portion of the processor

typedef TAdd#(NumCheckpoint,1) NumExecuteEpochs;
typedef Bit#(TLog#(NumExecuteEpochs)) ExecuteEpoch;
typedef 2 NumDecodeEpochs;
typedef Bit#(TLog#(NumDecodeEpochs)) DecodeEpoch;
typeclass Epoch#(type t);
    function t nextEpoch( t x );
endtypeclass

instance Epoch#(ExecuteEpoch);
    function ExecuteEpoch nextEpoch( ExecuteEpoch x );
        return (x == fromInteger(valueOf(NumExecuteEpochs)-1)) ? 0 : x + 1;
    endfunction
endinstance
instance Epoch#(DecodeEpoch);
    function DecodeEpoch nextEpoch( DecodeEpoch x );
        return (x == fromInteger(valueOf(NumDecodeEpochs)-1)) ? 0 : x + 1;
    endfunction
endinstance

// Types for instructions at various points inside the processor

typedef struct {
    Addr            pc;
    Addr            ppc;
    Data            inst;
    DecodeEpoch     dEpoch;
    ExecuteEpoch    eEpoch;
} FetchedInst deriving(Bits, Eq, FShow);

typedef struct {
    Addr                pc;
    Addr                ppc;
    IType               iType;
    AluFunc             aluFunc;
    BrFunc              brFunc;
    FullArchRegIndex    dst;
    FullArchRegIndex    src1;
    FullArchRegIndex    src2;
    Maybe#(Data)        imm;
} DecodedInst deriving(Bits, Eq, FShow);

typedef struct {
    Addr                    pc;
    Addr                    ppc;
    IType                   iType;
    AluFunc                 aluFunc;
    BrFunc                  brFunc;
    Maybe#(PhyRegIndex)     dstOldName;
    FullArchRegIndex        dstArchName;
    FullPhyRegIndex         dst;
    FullPhyRegIndex         src1;
    FullPhyRegIndex         src2;
    Maybe#(Data)            imm;
    Bit#(NumCheckpoint)     brBits;
    Maybe#(CheckpointTag)   checkpoint;
} RenamedInst deriving(Bits, Eq, FShow);

typedef struct {
    Addr                    pc;
    Addr                    ppc;
    IType                   iType;
    AluFunc                 aluFunc;
    BrFunc                  brFunc;
    FullPhyRegIndex         dst;
    FullPhyRegIndex         src1;
    FullPhyRegIndex         src2;
    Maybe#(Data)            imm;
    Bit#(NumCheckpoint)     brBits;
    Maybe#(CheckpointTag)   checkpoint;
    RobIndex                robTag;
} IssuedInst deriving(Bits, Eq, FShow);

typedef struct {
    Addr                    pc;
    Addr                    ppc;
    IType                   iType;
    AluFunc                 aluFunc;
    BrFunc                  brFunc;
    FullPhyRegIndex         dst;
    Data                    rVal1;
    Data                    rVal2;
    Data                    copVal;
    Maybe#(Data)            imm;
    Bit#(NumCheckpoint)     brBits;
    Maybe#(CheckpointTag)   checkpoint;
    RobIndex                robTag;
} IssuedInstWithData deriving (Bits, Eq, FShow);

typedef struct {
    Addr                    pc;
    IType                   iType;
    FullPhyRegIndex         dst;
    Data                    data;
    Addr                    addr;
    Bool                    mispredict;
    Bool                    brTaken;
    Bit#(NumCheckpoint)     brBits;
    Maybe#(CheckpointTag)   checkpoint;
    RobIndex                robTag;
} ExecutedInst deriving(Bits, Eq, FShow);

// RenamedInst + brTaken
typedef struct {
    Addr                    pc;
    Addr                    ppc;
    IType                   iType;
    AluFunc                 aluFunc;
    BrFunc                  brFunc;
    Maybe#(PhyRegIndex)     dstOldName;
    FullArchRegIndex        dstArchName;
    FullPhyRegIndex         dst;
    FullPhyRegIndex         src1;
    FullPhyRegIndex         src2;
    Maybe#(Data)            imm;
    Bit#(NumCheckpoint)     brBits;
    Maybe#(CheckpointTag)   checkpoint;
    Bool                    brTaken;
} CommittedInst deriving(Bits, Eq, FShow);

// Memory types
typedef struct {
    Addr                    pc;
    IType                   iType;
    FullPhyRegIndex         dst;
    FullPhyRegIndex         src1;
    FullPhyRegIndex         src2;
    Maybe#(Data)            imm;
    Bit#(NumCheckpoint)     brBits;
    RobIndex                robTag;
} MemIssuedInst deriving (Bits, Eq, FShow);

typedef struct {
    Addr                    pc;
    Addr                    addr;
    MemOp                   op;
    FullPhyRegIndex         dst;
    Data                    data;
    Bit#(NumCheckpoint)     brBits;
    RobIndex                robTag;
} MemReqInst deriving (Bits, Eq, FShow);

typedef struct {
    Addr                    pc;
    FullPhyRegIndex         dst;
    Data                    data;
    Bit#(NumCheckpoint)     brBits;
    RobIndex                robTag;
} MemRespInst deriving (Bits, Eq, FShow);

// Functions to pass shared values from one instruction type to the next

function DecodedInst toDecodedInst( FetchedInst x );
    return DecodedInst{
        pc:         x.pc,
        ppc:        x.ppc,
        iType:      ?,
        aluFunc:    ?,
        brFunc:     ?,
        dst:        ?,
        src1:       ?,
        src2:       ?,
        imm:        ?
    };
endfunction

function RenamedInst toRenamedInst( DecodedInst x );
    return RenamedInst{
        pc:             x.pc,
        ppc:            x.ppc,
        iType:          x.iType,
        aluFunc:        x.aluFunc,
        brFunc:         x.brFunc,
        dstOldName:     tagged Invalid,
        dstArchName:    x.dst,
        dst:            tagged Invalid,
        src1:           tagged Invalid,
        src2:           tagged Invalid,
        imm:            x.imm,
        brBits:         0,
        checkpoint:     tagged Invalid
    };
endfunction

function IssuedInst toIssuedInst( RenamedInst x );
    return IssuedInst{
        pc:         x.pc,
        ppc:        x.ppc,
        iType:      x.iType,
        aluFunc:    x.aluFunc,
        brFunc:     x.brFunc,
        dst:        x.dst,
        src1:       x.src1,
        src2:       x.src2,
        imm:        x.imm,
        brBits:     x.brBits,
        checkpoint: x.checkpoint,
        robTag:     0
    };
endfunction

function IssuedInstWithData toIssuedInstWithData( IssuedInst x );
    return IssuedInstWithData{
        pc:         x.pc,
        ppc:        x.ppc,
        iType:      x.iType,
        aluFunc:    x.aluFunc,
        brFunc:     x.brFunc,
        dst:        x.dst,
        rVal1:      0,
        rVal2:      0,
        copVal:     0,
        imm:        x.imm,
        brBits:     x.brBits,
        checkpoint: x.checkpoint,
        robTag:     x.robTag
    };
endfunction

function ExecutedInst toExecutedInst( IssuedInstWithData x );
    return ExecutedInst{
        pc:         x.pc,
        iType:      x.iType,
        dst:        x.dst,
        data:       0,
        addr:       0,
        mispredict: False,
        brTaken:    False,
        brBits:     x.brBits,
        checkpoint: x.checkpoint,
        robTag:     x.robTag
    };
endfunction

function CommittedInst toCommittedInst( RenamedInst x );
    return CommittedInst{
        pc:             x.pc,
        ppc:            x.ppc,
        iType:          x.iType,
        aluFunc:        x.aluFunc,
        brFunc:         x.brFunc,
        dstOldName:     x.dstOldName,
        dstArchName:    x.dstArchName,
        dst:            x.dst,
        src1:           x.src1,
        src2:           x.src2,
        imm:            x.imm,
        brBits:         x.brBits,
        checkpoint:     x.checkpoint,
        brTaken:        False
    };
endfunction

function MemIssuedInst toMemIssuedInst( RenamedInst x );
    return MemIssuedInst{
        pc:         x.pc,
        iType:      x.iType,
        dst:        x.dst,
        src1:       x.src1,
        src2:       x.src2,
        imm:        x.imm,
        brBits:     x.brBits,
        robTag:     0
    };
endfunction

function MemReqInst toMemReqInst( MemIssuedInst x );
    return MemReqInst{
        pc:     x.pc,
        addr:   0,
        op:     toMemOp(x.iType),
        dst:    x.dst,
        data:   0,
        brBits: x.brBits,
        robTag: x.robTag
    };
endfunction

function MemRespInst toMemRespInst( MemReqInst x );
    return MemRespInst{
        pc:     x.pc,
        dst:    x.dst,
        data:   x.data,
        brBits: x.brBits,
        robTag: x.robTag
    };
endfunction

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

Bit#(6) opLL    = 6'b110000;
Bit#(6) opSC    = 6'b111000;


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

    opJ, opJAL:
      ret = (opcode == opJ? $format("j ") : $format("jal ")) + $format("0x%0x", {target, 2'b00});

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
        rsMFC0:
          ret = $format("mfc0 r%0d = [r%0d]", rt, rd);
        rsMTC0:
          ret = $format("mtc0 [r%0d] = r%0d", rd, rt);
      endcase
    end

    opFUNC:
    case(funct)
      fcJR, fcJALR:
        ret = (funct == fcJR ? $format("jr") : $format("jalr")) + $format(" r%0d = r%0d", rd, rs);

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

    default:
      ret = $format("nop 0x%0x", inst);
  endcase

  return ret;

endfunction
