import Types::*;
import ProcTypes::*;
import CacheTypes::*;
import MemTypes::*;
import Fifo::*;
import Vector::*;
import NBCacheTypes::*;

typedef enum{Ready, WaitCacheResponse, WaitMemResponse} PPPState deriving(Eq, Bits, FShow);



module mkParentProtocolProcessor(MessageFifo#(n) r2m, MessageFifo#(n) m2r, WideMem mem, Empty ifc);

    Vector#(NumCaches, Vector#(CacheRows, Reg#(MSI))) child <- replicateM(replicateM(mkReg(unpack(0))));
    Vector#(NumCaches, Vector#(CacheRows, Reg#(Maybe#(MSI)))) waitc <- replicateM(replicateM(mkReg(tagged Invalid)));
    Vector#(NumCaches, Vector#(CacheRows, Reg#(CacheTag))) tags <- replicateM(replicateM(mkReg(unpack(0))));
    Reg#(Bool) memoryAccess <- mkReg(False);
    Reg#(Maybe#(CacheLine)) memResp <- mkReg(tagged Invalid);

    function Bool isCompatible(MSI a, MSI b);
      case (a)
        M: return (b == I);
        S: return (b != M);
        default: return True;
      endcase
    endfunction

    //Possible problem:
    //if only one cache, then tags[1] is undefined?
    // but why is 2 cores failing also?
    function Bool ruleTwoPossible;
      //changed for multiple caches
      //instead of ~c, needs to be true for all
      //i ~= c
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
        Vector#(NumCaches, Bool) possible = replicate(False);
        for (Integer i = 0; i < valueOf(NumCaches); i=i+1) begin
          if (c == fromInteger(i)) begin
            if ( (tags[i][getIndex(a)] == getTag(a) &&
                 waitc[i][getIndex(a)] == Invalid ) ||
                (tags[i][getIndex(a)] != getTag(a) ))
                possible[i] = True;
            else possible[i] = False;
          end else begin
            if ( (tags[i][getIndex(a)] == getTag(a) &&
             waitc[i][getIndex(a)] == Invalid &&
             isCompatible(child[i][getIndex(a)], y)) ||
             tags[i][getIndex(a)] != getTag(a) )
             possible[i] = True;
            else possible[i] = False;
          end
        end
        if (unpack(& pack(possible))) return True;
        else return False;
      end else return False;
    endfunction

    function Vector#(NumCaches, Bool) ruleFourPossible;
      //incoming msg == Req
      Vector#(NumCaches, Bool) possible = replicate(False);
      if ( r2m.first matches tagged Req .req &&& !memoryAccess ) begin
        let c = req.child;
        let a = req.addr;
        let y = req.state;
        for (Integer i = 0; i < valueOf(NumCaches); i=i+1) begin
          if (fromInteger(i) != c) begin
            if ( tags[i][getIndex(a)] == getTag(a) &&
                 //states aren't compatible
                 !isCompatible(child[i][getIndex(a)], y) &&
                 //not waiting on an outstanding request
                 waitc[i][getIndex(a)] == Invalid  ) begin
              possible[i] = True;
            end else possible[i] = False;
          end
        end
      end else possible = replicate(False);
      return possible;
    endfunction

    function Bool ruleSixPossible;
      if ( r2m.first matches tagged Resp .resp &&& !memoryAccess )
        return True;
      else return False;
      //return (!memoryAccess && r2m.first matches tagged Resp .resp);
    endfunction

    rule doMemAccess( memoryAccess );
      $display("============================");
      $display("ppp doMemAccess:");
      $display("============================");
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
        $display("============================");
        $display("ppp rule two:");
        $display("child: %x", c);
        $display("req addr: %x", a);
        $display("req state = ", fshow(y));
        if ( child[c][getIndex(a)] == S && y == M ) begin
          //immediately send response without querying memory
          m2r.enq_resp(CacheMemResp{child:c, addr:a, state:y, data:unpack(0)});
          child[c][getIndex(a)] <= y;
          r2m.deq;
          $display("immediate response");
          $display("============================");
        end else if (isValid(memResp)) begin
          //already queried memory
          m2r.enq_resp(CacheMemResp{child:c, addr:a, state:y, data:validValue(memResp)});
          if (validValue(memResp) == unpack(0)) $display("sending zero data");
          //set internal tag to new cache tag from request
          tags[c][getIndex(a)] <= getTag(a);
          memResp <= tagged Invalid;
          child[c][getIndex(a)] <= y;
          r2m.deq;
          $display("receive mem response");
          $display("============================");
        end else begin
          //need to query memory
          mem.req(WideMemReq{write_en:'0, addr:a, data:unpack(0)});
          memoryAccess <= True;
          $display("send mem req");
        end
      end
    endrule



    rule doFour( unpack(|pack(ruleFourPossible)) );
      let possible = ruleFourPossible;
      if ( r2m.first matches tagged Req .req) begin
        let newMessage = req;
        let c = newMessage.child;
        let a = newMessage.addr;
        let z = newMessage.state;
        $display("============================");
        $display("ppp rule four:");
        $display("child: %x", c);
        $display("req addr: %x", a);
        $display("req state = ", fshow(z));
        $display("downgrading children %x", possible);
        MSI y;
        if ( z == M) y = I;
        else y = S;
        $display("to =", fshow(y));
        for (Integer i = 0; i < valueOf(NumCaches); i=i+1) begin
          if (fromInteger(i) != c && possible[i]) begin
            waitc[i][getIndex(a)] <= tagged Valid y;
            m2r.enq_req(CacheMemReq{child:fromInteger(i), addr:a, state:y});
          end
        end
        $display("============================");
      end
    endrule






    rule doSix(ruleSixPossible);
      //r2m.first matches tagged Resp .resp;
      if ( r2m.first matches tagged Resp .resp) begin
        r2m.deq;
        let newMessage = resp;
        let c = newMessage.child;
        let a = newMessage.addr;
        let y = newMessage.state;
        let d = newMessage.data;
        $display("============================");
        $display("ppp rule six:");
        $display("child: %x", c);
        $display("resp addr: %x", a);
        $display("resp state = ", fshow(y));
        $display("resp data = %x", d);

        //if tags don't match, throw error here:
        if ( tags[c][getIndex(a)] != getTag(a) ) begin
          $fwrite(stderr, "ERROR: tags don't match in rule 6\n");
          $finish(1);
        end
        if ( child[c][getIndex(a)] == M ) begin
          $display("mem req:");
          $display("addr: %x", a);
          $display("data: %x", d);
          if (d == unpack(0)) $display("writing zero to data");
          mem.req(WideMemReq{write_en:'1, addr:a, data:d});
        end

        child[c][getIndex(a)] <= y;

        //figure out the tagged matches syntax
        if ( isValid(waitc[c][getIndex(a)]) && validValue(waitc[c][getIndex(a)]) >= y ) waitc[c][getIndex(a)] <= Invalid;
        $display("============================");
      end
    endrule

endmodule
