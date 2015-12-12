import Types::*;
import ProcTypes::*; // from lab 7
import MemTypes::*;
import Vector::*;

// Enumerations
//// typedef enum { CacheReady, CacheWriteReq, CacheReadReq, CacheReadResp } CacheState deriving( Bits, Eq, FShow );
//// typedef enum { Req, Resp } ReqResp deriving( Eq, Bits, FShow );
typedef enum { M, S, I } MSI deriving( Bits, Eq, FShow );
instance Ord#(MSI);
    function Bool \< ( MSI x, MSI y );
        let c = compare(x,y);
        return (c == LT);
    endfunction
    function Bool \<= ( MSI x, MSI y );
        let c = compare(x,y);
        return (c == LT) || (c == EQ);
    endfunction
    function Bool \> ( MSI x, MSI y );
        let c = compare(x,y);
        return (c == GT);
    endfunction
    function Bool \>= ( MSI x, MSI y );
        let c = compare(x,y);
        return (c == GT) || (c == EQ);
    endfunction

    // This should implement M > S > I
    function Ordering compare( MSI x, MSI y );
        if( x == y ) begin
            // MM SS II
            return EQ;
        end else if( x == M || y == I) begin
            // MS MI SI
            return GT;
        end else begin
            // SM IM IS
            return LT;
        end
    endfunction

    function MSI min( MSI x, MSI y );
        if( x < y ) begin
            return x;
        end else begin
            return y;
        end
    endfunction
    function MSI max( MSI x, MSI y );
        if( x > y ) begin
            return x;
        end else begin
            return y;
        end
    endfunction
endinstance

// Sizes
typedef 16 CacheLineWords; // to match DDR3 width
typedef 8 CacheRows;
typedef 2 NumCaches;

// Data Types
typedef Bit#( TSub#(TSub#(30,TLog#(CacheRows)),TLog#(CacheLineWords)) ) CacheTag;
typedef TSub#(TSub#(30,TLog#(CacheRows)),TLog#(CacheLineWords)) CacheTagSz;
typedef Bit#( TLog#(CacheRows) ) CacheIndex;
typedef TLog#(CacheRows) CacheIndexSz;
typedef Bit#( TLog#(CacheLineWords) ) CacheWordSelect;
typedef Bit#( TLog#(CacheLineWords) ) CacheOffset;
typedef Vector#(CacheLineWords, Data) CacheLine;
typedef Bit#(TLog#(NumCaches)) CacheID;

// Structures
typedef struct{
    CacheID     child;
    Addr        addr;
    MSI         state;
    CacheLine   data;
} CacheMemResp deriving(Eq, Bits, FShow);
typedef struct{
    CacheID     child;
    Addr        addr;
    MSI         state;
} CacheMemReq deriving(Eq, Bits, FShow);
typedef union tagged {
    CacheMemReq     Req;
    CacheMemResp    Resp;
} CacheMemMessage deriving(Eq, Bits, FShow);

typedef struct{
    Bit#(CacheLineWords)    write_en;   // Word write enable (16 to match DDR3)
    Addr                    addr;
    CacheLine               data;       // Vector#(CacheLineWords, Data)
} WideMemReq deriving(Eq,Bits);

interface WideMem;
    method Action req(WideMemReq r);
    method ActionValue#(CacheLine) resp;
endinterface

// Functions
function WideMemReq toWideMemReq( MemReq req );
    CacheWordSelect word_sel = truncate( req.addr >> 2 );
    WideMemReq ret = ?;
    ret.write_en = 0;
    if( req.op == St ) begin
        ret.write_en[word_sel] = 1;
    end
    ret.addr = req.addr & 32'hFFFFFFE0;
    ret.addr = req.addr;
    ret.data = replicate(req.data);
    return ret;
endfunction

interface MessageFifo#(numeric type size);
    method Action enq_resp( CacheMemResp d );
    method Action enq_req( CacheMemReq d );
    method Bool hasResp;
    method Bool hasReq;
    method Bool notEmpty;
    method CacheMemMessage first;
    method Action deq;
endinterface
