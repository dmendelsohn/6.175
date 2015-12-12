import StmtFSM::*;
import Vector::*;

import MessageFifo::*;
import MessageRouter::*;
import CacheTypes::*;

// This tests some things about the message router:
//  1) Messages get routed from children to the parent
//  2) Messages from the parent get sent to the right child
//  3) If the network is full of requests, responses can still pass through
//  4) If one of the r2c FIFOs is full but m2r is empty, messages can get sent to the other r2c FIFO

(* synthesize *)
module mkMessageRouterTest(Empty);
    // Set this to true to see more messages displayed to stdout
    Bool debug = False;

    // cache to router
    Vector#(NumCaches, MessageFifo#(2)) c2r <- replicateM(mkMessageFifo);
    // router to cache
    Vector#(NumCaches, MessageFifo#(2)) r2c <- replicateM(mkMessageFifo);
    // router to memory
    MessageFifo#(2) r2m <- mkMessageFifo;
    // memory to router
    MessageFifo#(2) m2r <- mkMessageFifo;

    let router <- mkMessageRouter( c2r, r2c, m2r, r2m );

    function Action checkpoint(Integer i);
        return (action
                    if( debug ) begin
                        $display("Checkpoint %0d", i);
                    end
                endaction);
    endfunction

    // wait until message comes
    function Action getMessage(MessageFifo#(2) fifo, CacheMemMessage m);
        return (action
                    if( m == fifo.first ) begin
                        // all is good
                        fifo.deq();
                    end else begin
                        $fwrite(stderr, "ERROR: Expected message didn't match message_fifo.first\n");
                        $fwrite(stderr, "    Expected message = ", fshow(m), "\n");
                        $fwrite(stderr, "    message_fifo.first = ", fshow(m), "\n");
                        $finish(1);
                    end
                endaction);
    endfunction

    function Action wait_for_message(MessageFifo#(2) fifo) = when( fifo.notEmpty, noAction );
    function Action wait_for_resp(MessageFifo#(2) fifo) = when( fifo.hasResp, noAction );

    function CacheMemReq generic_request(CacheID child) = CacheMemReq{ child: child, addr: 100, state: S };
    function CacheMemResp generic_response(CacheID child) = CacheMemResp{ child: child, addr: 200, state: S, data: unpack(0) };

    // This uses StmtFSM to create an FSM for testing
    // See the bluespec reference guide for more info
    Stmt test = (seq
                    checkpoint(0);
                    c2r[0].enq_req( generic_request(0) );
                    c2r[1].enq_req( generic_request(1) );
                    getMessage( r2m, tagged Req generic_request(0) );
                    getMessage( r2m, tagged Req generic_request(1) );
                    
                    checkpoint(1);
                    c2r[0].enq_resp( generic_response(0) );
                    c2r[1].enq_resp( generic_response(1) );
                    getMessage( r2m, tagged Resp generic_response(0) );
                    getMessage( r2m, tagged Resp generic_response(1) );

                    checkpoint(2);
                    c2r[0].enq_req( generic_request(0) );
                    c2r[1].enq_resp( generic_response(1) );
                    wait_for_resp( r2m );
                    getMessage( r2m, tagged Resp generic_response(1) );
                    getMessage( r2m, tagged Req generic_request(0) );

                    checkpoint(3);
                    c2r[1].enq_req( generic_request(1) );
                    c2r[0].enq_resp( generic_response(0) );
                    wait_for_resp( r2m );
                    getMessage( r2m, tagged Resp generic_response(0) );
                    getMessage( r2m, tagged Req generic_request(1) );

                    checkpoint(4);
                    // fill up the message network with requests form one core
                    c2r[1].enq_req( generic_request(1) );
                    c2r[1].enq_req( generic_request(1) );
                    c2r[1].enq_req( generic_request(1) );
                    c2r[1].enq_req( generic_request(1) );

                    checkpoint(5);
                    // send responses
                    c2r[0].enq_resp( generic_response(0) );
                    c2r[1].enq_resp( generic_response(1) );
                    wait_for_resp( r2m );
                    getMessage( r2m, tagged Resp generic_response(0) );
                    wait_for_resp( r2m );
                    getMessage( r2m, tagged Resp generic_response(1) );

                    checkpoint(6);
                    // dequeue requests
                    r2m.deq;
                    r2m.deq;
                    r2m.deq;
                    r2m.deq;

                    checkpoint(7);
                    // fill up the message netowrk with requests from two cores
                    c2r[1].enq_req( generic_request(1) );
                    c2r[1].enq_req( generic_request(1) );
                    c2r[1].enq_req( generic_request(1) );
                    c2r[1].enq_req( generic_request(1) );
                    c2r[0].enq_req( generic_request(1) );
                    c2r[0].enq_req( generic_request(1) );

                    checkpoint(8);
                    // send responses
                    c2r[0].enq_resp( generic_response(0) );
                    c2r[1].enq_resp( generic_response(1) );
                    wait_for_resp( r2m );
                    getMessage( r2m, tagged Resp generic_response(0) );
                    wait_for_resp( r2m );
                    getMessage( r2m, tagged Resp generic_response(1) );

                    checkpoint(9);
                    // dequeue requests
                    r2m.deq;
                    r2m.deq;
                    r2m.deq;
                    r2m.deq;
                    r2m.deq;
                    r2m.deq;

                    // Now lets test child to parent

                    checkpoint(10);
                    m2r.enq_req( generic_request(1) );
                    m2r.enq_req( generic_request(0) );
                    getMessage( r2c[1], tagged Req generic_request(1) );
                    getMessage( r2c[0], tagged Req generic_request(0) );

                    checkpoint(11);
                    m2r.enq_resp( generic_response(1) );
                    m2r.enq_resp( generic_response(0) );
                    getMessage( r2c[1], tagged Resp generic_response(1) );
                    getMessage( r2c[0], tagged Resp generic_response(0) );

                    checkpoint(12);
                    // Fill up r2c[0]
                    m2r.enq_req( generic_request(0) );
                    m2r.enq_req( generic_request(0) );
                    m2r.enq_resp( generic_response(0) );
                    m2r.enq_resp( generic_response(0) );
                    // Fill up r2c[1]
                    m2r.enq_req( generic_request(1) );
                    m2r.enq_req( generic_request(1) );
                    m2r.enq_resp( generic_response(1) );
                    m2r.enq_resp( generic_response(1) );
                    // Drain r2c[1]
                    getMessage( r2c[1], tagged Resp generic_response(1) );
                    getMessage( r2c[1], tagged Resp generic_response(1) );
                    getMessage( r2c[1], tagged Req generic_request(1) );
                    getMessage( r2c[1], tagged Req generic_request(1) );
                    // Drain r2c[0]
                    getMessage( r2c[0], tagged Resp generic_response(0) );
                    getMessage( r2c[0], tagged Resp generic_response(0) );
                    getMessage( r2c[0], tagged Req generic_request(0) );
                    getMessage( r2c[0], tagged Req generic_request(0) );

                    $display("PASSED");
                    $finish(0);
                endseq);
    mkAutoFSM(test);

    // Timeout FSM
    // If the test doesn't finish in 1000 cycles, this prints an error
    Stmt timeout = (seq
                        delay(1000);
                        (action
                            $fwrite(stderr, "ERROR: Testbench stalled.\n");
                            if(!debug) $fwrite(stderr, "Set debug to true in mkMessageFifoTest and recompile to get more info\n");
                        endaction);
                        $finish(1);
                    endseq);
    mkAutoFSM(timeout);
endmodule
