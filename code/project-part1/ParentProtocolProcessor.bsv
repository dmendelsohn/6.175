import Types::*;
import ProcTypes::*;
import CacheTypes::*;
import MemTypes::*;
import Fifo::*;
import Vector::*;
import NBCacheTypes::*;

typedef enum{Ready, WaitCacheResponse, WaitMemResponse} PPPState deriving(Eq, Bits, FShow);



module mkParentProtocolProcessor(MessageFifo#(n) r2m, MessageFifo#(n) m2r, WideMem mem, Empty ifc);
    // TODO: implement the parent protocol processor

    Vector#(NumCaches, Vector#(CacheRows, Reg#(MSI))) child <- replicateM(replicateM(mkRegU()));
    Vector#(NumCaches, Vector#(CacheRows, Reg#(Maybe#(MSI)))) waitc <- replicateM(replicateM(mkRegU()));
    Vector#(NumCaches, Vector#(CacheRows, Reg#(CacheTag))) tags <- replicateM(replicateM(mkRegU()));
    Reg#(Bool) memoryAccess <- mkReg(False);
    Reg#(Maybe#(CacheLine)) memResp <- mkRegU();

    function Bool isCompatible(MSI a, MSI b);
      case (a)
        M: return (b == I);
        S: return (b != M);
        default: return True;
      endcase
      //(M,I)
      //(S,S)
      //(S,I)
      //(I,I)
      //(I,S)
      //(I,M)
    endfunction

    function Bool ruleTwoPossible;
      /*
      these must be true:
      memoryAccess == False
      if tag[0] matches:
        waitc[0][getIndex(a)] == No
      if tag[1] matches:
        waitc[1][getIndex(a)] == No
      incoming msg == Req
      let c = req.child
      if tag[~c] matches:
        //only 2 caches, so only one other cache, can refer with ~c
        isCompatible(child[~c][getIndex(a)], req.state)
      */
      if ( r2m.first matches tagged Req .req &&& !memoryAccess ) begin
        let newMessage = req;
        let a = req.addr;
        let c = req.child;
        let y = req.state;
        //only 2 caches, so only one other cache, can refer with ~c
        if (
          (tags[c][getIndex(a)] == getTag(a) &&
                        waitc[c][getIndex(a)] == Invalid ||
             tags[c][getIndex(a)] != getTag(a))

             &&

             ((tags[~c][getIndex(a)] == getTag(a) &&
             waitc[~c][getIndex(a)] == Invalid &&
             isCompatible(child[~c][getIndex(a)], y)) ||
             tags[~c][getIndex(a)] != getTag(a))
           )

           return True;
        else return False;
      end else return False;

    endfunction

    function Bool ruleFourPossible;
      //incoming msg == Req
      Bool test1 = False;
      if ( r2m.first matches tagged Req .req &&& !memoryAccess ) begin
        let c = req.child;
        let a = req.addr;
        let y = req.state;
        //tags match
        //only 2 caches, so only one other cache, can refer with ~c
        if ( tags[~c][getIndex(a)] == getTag(a) &&
          //states aren't compatible
          !isCompatible(child[~c][getIndex(a)], y) &&
          //not waiting on an outstanding request
          waitc[~c][getIndex(a)] == Invalid ) begin
          test1 = True;
        end else begin
          test1 = False;
        end
      end else begin
        test1 = False;
      end
      return test1;
    endfunction

    function Bool ruleSixPossible;
      if ( r2m.first matches tagged Resp .resp &&& !memoryAccess )
        return True;
      else return False;
      //return (!memoryAccess && r2m.first matches tagged Resp .resp);
    endfunction

    rule doMemAccess( memoryAccess );
      CacheLine resp <- mem.resp();
      //complete rule two
      memResp <= tagged Valid resp;
      memoryAccess <= False;
    endrule

    rule doTwo( ruleTwoPossible );
      if ( r2m.first matches tagged Req .req) begin
        let newMessage = req;
        let c = newMessage.child;
        let a = newMessage.addr;
        let y = newMessage.state;
        if ( child[c][getIndex(a)] == S && y == M ) begin
          //immediately send response without querying memory
          m2r.enq_resp(CacheMemResp{child:c, addr:a, state:y, data:unpack(0)});
          child[c][getIndex(a)] <= y;
          r2m.deq;
        end else if (isValid(memResp)) begin
          //already queried memory
          m2r.enq_resp(CacheMemResp{child:c, addr:a, state:y, data:validValue(memResp)});
          //set internal tag to new cache tag from request
          tags[c][getIndex(a)] <= getTag(a);
          memResp <= Invalid;
          child[c][getIndex(a)] <= y;
          r2m.deq;
        end else begin
          //need to query memory
          mem.req(WideMemReq{write_en:'0, addr:a, data:unpack(0)});
          memoryAccess <= True;
        end
      end
    endrule



    rule doFour( ruleFourPossible );
      if ( r2m.first matches tagged Req .req) begin
        let newMessage = req;
        let c = newMessage.child;
        let a = newMessage.addr;
        let z = newMessage.state;
        MSI y;
        if ( z == M) y = I;
        else y = S;
        //only 2 caches, so only one other cache, can refer with ~c
        waitc[~c][getIndex(a)] <= tagged Valid y;
        //only 2 caches, so only one other cache, can refer with ~c
        m2r.enq_req(CacheMemReq{child:~c, addr:a, state:y});
      end
    endrule






    rule doSix( ruleSixPossible );
      //r2m.first matches tagged Resp .resp;
      r2m.deq;
      if ( r2m.first matches tagged Resp .resp) begin
        let newMessage = resp;
        let c = newMessage.child;
        let a = newMessage.addr;
        let y = newMessage.state;
        let d = newMessage.data;
        //if tags don't match, throw error here:
        if ( tags[c][getIndex(a)] != getTag(a) ) begin
          $fwrite(stderr, "ERROR: tags don't match in rule 6\n");
          $finish(1);
        end
        if ( child[c][getIndex(a)] == M ) begin
          mem.req(WideMemReq{write_en:'1, addr:a, data:d});
        end

        child[c][getIndex(a)] <= y;

        //figure out the tagged matches syntax
        if ( isValid(waitc[c][getIndex(a)]) && validValue(waitc[c][getIndex(a)]) >= y ) waitc[c][getIndex(a)] <= Invalid;
      end
    endrule

endmodule
