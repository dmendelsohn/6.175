import ProcTypes::*;

// This file will contain some type classes used for convenience throughout the processor

// HasBranchBits#(t) type class
//   used in pipeline stage fifos for poisoning instructions with specific branch dependencies

typeclass HasBranchBits#(type t);
    function Bit#(NumCheckpoint) getBranchBits(t x);
    function Bool getBranchBit(t x, CheckpointTag i);
    function t clearBranchBit(t x, CheckpointTag i);
endtypeclass

// for debugging
instance HasBranchBits#( Bit#(n) ) provisos (Add#(NumCheckpoint, _a, n));
    function Bit#(NumCheckpoint) getBranchBits( Bit#(n) x );
        return x[valueOf(n)-1:0];
    endfunction
    function Bool getBranchBit( Bit#(n) x, CheckpointTag i );
        return unpack(x[i]);
    endfunction
    function Bit#(n) clearBranchBit( Bit#(n) x, CheckpointTag i );
        let ret = x;
        ret[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( Bit#(NumCheckpoint) );
    function Bit#(NumCheckpoint) getBranchBits( Bit#(NumCheckpoint) x );
        return x;
    endfunction
    function Bool getBranchBit( Bit#(NumCheckpoint) x, CheckpointTag i );
        return unpack(getBranchBits(x)[i]);
    endfunction
    function Bit#(NumCheckpoint) clearBranchBit( Bit#(NumCheckpoint) x, CheckpointTag i );
        let ret = x;
        ret[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( RenamedInst );
    function Bit#(NumCheckpoint) getBranchBits( RenamedInst x );
        return x.brBits;
    endfunction
    function Bool getBranchBit( RenamedInst x, CheckpointTag i );
        return unpack(x.brBits[i]);
    endfunction
    function RenamedInst clearBranchBit( RenamedInst x, CheckpointTag i );
        let ret = x;
        ret.brBits[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( IssuedInst );
    function Bit#(NumCheckpoint) getBranchBits( IssuedInst x );
        return x.brBits;
    endfunction
    function Bool getBranchBit( IssuedInst x, CheckpointTag i );
        return unpack(x.brBits[i]);
    endfunction
    function IssuedInst clearBranchBit( IssuedInst x, CheckpointTag i );
        let ret = x;
        ret.brBits[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( IssuedInstWithData );
    function Bit#(NumCheckpoint) getBranchBits( IssuedInstWithData x );
        return x.brBits;
    endfunction
    function Bool getBranchBit( IssuedInstWithData x, CheckpointTag i );
        return unpack(x.brBits[i]);
    endfunction
    function IssuedInstWithData clearBranchBit( IssuedInstWithData x, CheckpointTag i );
        let ret = x;
        ret.brBits[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( ExecutedInst );
    function Bit#(NumCheckpoint) getBranchBits( ExecutedInst x );
        return x.brBits;
    endfunction
    function Bool getBranchBit( ExecutedInst x, CheckpointTag i );
        return unpack(x.brBits[i]);
    endfunction
    function ExecutedInst clearBranchBit( ExecutedInst x, CheckpointTag i );
        let ret = x;
        ret.brBits[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( MemIssuedInst );
    function Bit#(NumCheckpoint) getBranchBits( MemIssuedInst x );
        return x.brBits;
    endfunction
    function Bool getBranchBit( MemIssuedInst x, CheckpointTag i );
        return unpack(x.brBits[i]);
    endfunction
    function MemIssuedInst clearBranchBit( MemIssuedInst x, CheckpointTag i );
        let ret = x;
        ret.brBits[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( MemReqInst );
    function Bit#(NumCheckpoint) getBranchBits( MemReqInst x );
        return x.brBits;
    endfunction
    function Bool getBranchBit( MemReqInst x, CheckpointTag i );
        return unpack(x.brBits[i]);
    endfunction
    function MemReqInst clearBranchBit( MemReqInst x, CheckpointTag i );
        let ret = x;
        ret.brBits[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( MemRespInst );
    function Bit#(NumCheckpoint) getBranchBits( MemRespInst x );
        return x.brBits;
    endfunction
    function Bool getBranchBit( MemRespInst x, CheckpointTag i );
        return unpack(x.brBits[i]);
    endfunction
    function MemRespInst clearBranchBit( MemRespInst x, CheckpointTag i );
        let ret = x;
        ret.brBits[i] = 0;
        return ret;
    endfunction
endinstance

instance HasBranchBits#( Mispredict );
    function Bit#(NumCheckpoint) getBranchBits( Mispredict x );
        return x.brBits;
    endfunction
    function Bool getBranchBit( Mispredict x, CheckpointTag i );
        return unpack(x.brBits[i]);
    endfunction
    function Mispredict clearBranchBit( Mispredict x, CheckpointTag i );
        let ret = x;
        ret.brBits[i] = 0;
        return ret;
    endfunction
endinstance

// RegIndexType#(t) type class

// XXX: This isn't actually a type class anymore

function Bool isGpr(FullRegIndex#(gprType) x);
    if( x matches tagged Gpr .r ) begin
        return True;
    end else begin
        return False;
    end
endfunction
function gprType getGpr(FullRegIndex#(gprType) x);
    if( x matches tagged Gpr .r ) begin
        return r;
    end else begin
        return ?;
    end
endfunction
function Bool isCop0(FullRegIndex#(gprType) x);
    if( x matches tagged Cop0 .r ) begin
        return True;
    end else begin
        return False;
    end
endfunction
function CopRegIndex getCop0(FullRegIndex#(gprType) x);
    if( x matches tagged Cop0 .r ) begin
        return r;
    end else begin
        return ?;
    end
endfunction

