import CacheTypes::*;
import Fifo::*;

module mkMessageFifo(MessageFifo#(n));
    Fifo#(n, CacheMemMessage) resp_fifo <- mkCFFifo();
    Fifo#(n, CacheMemMessage) req_fifo <- mkCFFifo();

    method Action enq_resp( CacheMemResp d );
      resp_fifo.enq(tagged Resp d);
    endmethod

    method Action enq_req( CacheMemReq d );
      req_fifo.enq(tagged Req d);
    endmethod

    method Bool hasResp = resp_fifo.notEmpty;
    method Bool hasReq = req_fifo.notEmpty;
    method Bool notEmpty = resp_fifo.notEmpty || req_fifo.notEmpty;

    method CacheMemMessage first;
      if ( resp_fifo.notEmpty ) return resp_fifo.first;
      else return req_fifo.first;
    endmethod

    method Action deq if( resp_fifo.notEmpty || req_fifo.notEmpty );
      if ( resp_fifo.notEmpty ) resp_fifo.deq;
      else req_fifo.deq;
    endmethod
endmodule

