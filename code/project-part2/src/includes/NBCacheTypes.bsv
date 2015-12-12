import Types::*;
import ProcTypes::*;
import MemTypes::*;
import CacheTypes::*;

function CacheOffset getOffset(Addr addr);
    return truncate(addr >> 2);
endfunction

function CacheIndex getIndex(Addr addr);
    return truncate(addr >> (2 + valueOf(TLog#(CacheLineWords))));
endfunction

function CacheTag getTag(Addr addr);
    return truncateLSB(addr);
endfunction

// // Defined in ProcTypes.bsv
// typedef 8 NBCacheSize;
// typedef 4 StQSz;
// typedef 4 LdBuffSz;
// 
// typedef Bit#(TLog#(NBCacheSize)) NBCacheToken;
// 
// typedef struct {
//     Addr            addr;
//     Data            data;
//     MemOp           op;     // ld, ll, st, sc
//     NBCacheToken    token;  // ld, ll, sc
// } NBCacheReq deriving(Bits, Eq, FShow);
// typedef struct {
//     Data            data;
//     NBCacheToken    token;
// } NBCacheResp deriving(Bits, Eq, FShow);
// 
// // NBCache interface
// typedef ProcMemory#(NBCacheReq, NBCacheResp) NBCache;
