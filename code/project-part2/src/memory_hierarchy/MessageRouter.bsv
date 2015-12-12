import Vector::*;

import CacheTypes::*;
import MessageFifo::*;
import Ehr::*;
typedef enum {Ready, Fire} MsgRouterStatus deriving (Bits, Eq);
module mkMessageRouter(  Vector#(NumCaches,MessageFifo#(n)) c2r,
                         Vector#(NumCaches,MessageFifo#(n)) r2c,
                         MessageFifo#(n) m2r,
                         MessageFifo#(n) r2m,
                         Empty ifc );
    Ehr#(TAdd#(NumCaches,1), Maybe#(Bit#(TLog#(NumCaches)))) respEhr <- mkEhr(tagged Invalid);
    Ehr#(TAdd#(NumCaches,1), Maybe#(Bit#(TLog#(NumCaches)))) reqEhr <- mkEhr(tagged Invalid);
    // you can assume that NumCaches is 2
    Reg#(MsgRouterStatus) status <- mkReg(Ready);
    rule canonicalize1(status == Ready);

      //$display("num caches = %x", valueOf(NumCaches));
      for (Integer i = 0; i < valueOf(NumCaches); i=i+1) begin
        if ( c2r[i].notEmpty ) begin
          //add everything to req ehr, but only look at it
          //if there's no responses
          reqEhr[i] <= tagged Valid fromInteger(i);
          if ( c2r[i].first matches tagged Resp .resp ) begin
            respEhr[i] <= tagged Valid fromInteger(i);
          end
        end
      end
      status <= Fire;
    endrule

    rule canonicalize2(status == Fire);
      //valid responses
      if (isValid(respEhr[valueOf(NumCaches)])) begin
        //highest cache number w/ response:
        let respCache = validValue(respEhr[valueOf(NumCaches)]);
        if ( c2r[respCache].notEmpty ) begin
          c2r[respCache].deq;
          //need to separate tag from response proper
          //if statement should always pass
          if ( c2r[respCache].first matches tagged Resp .resp ) begin
            r2m.enq_resp(resp);
          end
        end
      //one of the caches is not empty
      //must be a request
      end else if (isValid(reqEhr[valueOf(NumCaches)])) begin
        //highest cache number w/ request:
        let reqCache = validValue(reqEhr[valueOf(NumCaches)]);
        if ( c2r[reqCache].notEmpty ) begin
          c2r[reqCache].deq;
          //need to separate tag from request proper
          //if statement should always pass
          if ( c2r[reqCache].first matches tagged Req .req ) begin
            r2m.enq_req(req);
          end
        end
      end
      //invalidate ehr's after writing+reading data by
      //setting highest port to invalid
      respEhr[valueOf(NumCaches)] <= tagged Invalid;
      reqEhr[valueOf(NumCaches)] <= tagged Invalid;

      status <= Ready;
    endrule

    rule reverseCanonicalize;
      if ( m2r.notEmpty ) begin
        m2r.deq;
        let toCache = m2r.first;

        case( toCache ) matches
          tagged Resp .resp:
          begin
            // handle CacheMemResp resp
            r2c[resp.child].enq_resp(resp);
          end
          tagged Req .req:
          begin
            // handle CacheMemReq req
            r2c[req.child].enq_req(req);
          end
        endcase
      end
    endrule

//    //message in both cache fifos
//    if ( c2r[0].notEmpty && c2r[1].notEmpty ) begin
//      // choose response over request
//      if ( c2r[1].first matches tagged Resp .resp ) begin
//        c2r[1].deq;
//        r2m.enq_resp(resp);
//        $display("cache 1 enqueing response");
//      //zero could have response, or else arbitrarily pick zero's request
//      end else if ( c2r[0].first matches tagged Resp .resp ) begin
//        c2r[0].deq;
//        r2m.enq_resp(resp);
//        $display("cache 0 enqueing response");

//      // if statement should always be true if we get here
//      end else if ( c2r[0].first matches tagged Req .req ) begin
//        c2r[0].deq;
//        r2m.enq_req(req);
//        $display("cache 0 enqueing request");

//      end

//    // only zero is not empty
//    end else if ( c2r[0].notEmpty ) begin
//      c2r[0].deq;
//      let newMessage = c2r[0].first;
//      case (newMessage) matches
//        tagged Resp .resp:
//        begin
//          // handle CacheMemResp resp
//          r2m.enq_resp(resp);
//          $display("cache 0 enqueing resp");
//        end

//        tagged Req .req:
//        begin
//          // handle CacheMemReq req
//          r2m.enq_req(req);
//          $display("cache 0 enqueing req");
//        end
//      endcase

//    //only one is not empty
//    end else if ( c2r[1].notEmpty ) begin
//      c2r[1].deq;
//      let newMessage = c2r[1].first;
//      case (newMessage) matches
//        tagged Resp .resp:
//        begin
//          // handle CacheMemResp resp
//          r2m.enq_resp(resp);
//          $display("cache 1 enqueing resp");
//        end

//        tagged Req .req:
//        begin
//          // handle CacheMemReq req
//          r2m.enq_req(req);
//          $display("cache 1 enqueing req");
//        end
//      endcase
//    end



//    if ( m2r.notEmpty ) begin
//      m2r.deq;
//      let toCache = m2r.first;

//      case( toCache ) matches
//        tagged Resp .resp:
//        begin
//          // handle CacheMemResp resp
//          if ( resp.child == 0 ) begin
//            r2c[0].enq_resp(resp);
//          end else r2c[1].enq_resp(resp);
//        end
//        tagged Req .req:
//        begin
//          // handle CacheMemReq req
//          if ( req.child == 0 ) begin
//            r2c[0].enq_req(req);
//          end else r2c[1].enq_req(req);
//        end
//      endcase
//    end
endmodule

