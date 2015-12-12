import ProcTypes::*;
import Vector::*;

// Enumerations
typedef enum { Req, Resp } ReqResp deriving( Eq, Bits, FShow );
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
typedef NumCores NumCaches;
typedef Bit#(TLog#(NumCaches)) CacheID;
typedef 8 MessageFifoSize;

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

// Interfaces
interface MessageFifo#( numeric type n );
    method Action enq_resp( CacheMemResp d );
    method Action enq_req( CacheMemReq d );
    method Bool hasResp;
    method Bool hasReq;
    method Bool notEmpty;
    method CacheMemMessage first;
    method Action deq;
endinterface

