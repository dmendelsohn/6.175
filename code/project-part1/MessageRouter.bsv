import Vector::*;

import CacheTypes::*;
import MessageFifo::*;

module mkMessageRouter(  Vector#(NumCaches,MessageFifo#(n)) c2r,
                         Vector#(NumCaches,MessageFifo#(n)) r2c,
                         MessageFifo#(n) m2r,
                         MessageFifo#(n) r2m,
                         Empty ifc );
    // you can assume that NumCaches is 2
    rule canonicalize;

      //message in both cache fifos
      if ( c2r[0].notEmpty && c2r[1].notEmpty ) begin
        // choose response over request
        if ( c2r[1].first matches tagged Resp .resp ) begin
          c2r[1].deq;
          r2m.enq_resp(resp);
        //zero could have response, or else arbitrarily pick zero's request
        end else if ( c2r[0].first matches tagged Resp .resp ) begin
          c2r[0].deq;
          r2m.enq_resp(resp);

        // if statement should always be true if we get here
        end else if ( c2r[0].first matches tagged Req .req ) begin
          c2r[0].deq;
          r2m.enq_req(req);
        end

      // only zero is not empty
      end else if ( c2r[0].notEmpty ) begin
        c2r[0].deq;
        let newMessage = c2r[0].first;
        case (newMessage) matches
          tagged Resp .resp:
          begin
            // handle CacheMemResp resp
            r2m.enq_resp(resp);
          end

          tagged Req .req:
          begin
            // handle CacheMemReq req
            r2m.enq_req(req);
          end
        endcase

      //only one is not empty
      end else if ( c2r[1].notEmpty ) begin
        c2r[1].deq;
        let newMessage = c2r[1].first;
        case (newMessage) matches
          tagged Resp .resp:
          begin
            // handle CacheMemResp resp
            r2m.enq_resp(resp);
          end

          tagged Req .req:
          begin
            // handle CacheMemReq req
            r2m.enq_req(req);
          end
        endcase
      end

      if ( m2r.notEmpty ) begin
        m2r.deq;
        let toCache = m2r.first;

        case( toCache ) matches
          tagged Resp .resp:
          begin
            // handle CacheMemResp resp
            if ( resp.child == 0 ) begin
              r2c[0].enq_resp(resp);
            end else r2c[1].enq_resp(resp);
          end
          tagged Req .req:
          begin
            // handle CacheMemReq req
            if ( req.child == 0 ) begin
              r2c[0].enq_req(req);
            end else r2c[1].enq_req(req);
          end
        endcase
      end
    endrule
endmodule

