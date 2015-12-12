import RegFile::*;
import StmtFSM::*;
import Vector::*;

import Fifo::*;
import Types::*;
import CacheTypes::*;
import MessageFifo::*;
import ParentProtocolProcessor::*;

// Dummy WideMem module for testing
module mkWideMemRegFile(WideMem);
    RegFile#(Bit#(16), CacheLine) rf <- mkRegFileFull;
    Fifo#(2, CacheLine) respQ <- mkCFFifo;

    method Action req(WideMemReq r);
        // All the requests in this program are to address 0, so if this is a request to some other address, throw an error
        if( r.addr != 0 ) begin
            $fwrite(stderr, "ERROR: main memory got a request for an address other than 0.\n");
            $finish(1);
        end
        if( r.write_en == 0 ) begin
            respQ.enq(rf.sub(truncate(r.addr >> 6)));
        end else if( r.write_en == '1 ) begin
            rf.upd( truncate(r.addr >> 6), r.data );
        end else begin
            // This shouldn't be used
            $fwrite(stderr, "ERROR: write_en in mkWideMemRegFile.req() is trying to write only some of the words in a cache line\n");
            $finish(1);
        end
    endmethod
    method ActionValue#(CacheLine) resp;
        respQ.deq;
        return respQ.first;
    endmethod
endmodule

// This tests the cache hierarchy parent with requests and responses for a single address
(* synthesize *)
module mkPPPTest(Empty);
    // Set this to true to see more messages displayed to stdout
    Bool debug = True;

    MessageFifo#(8) toParent <- mkMessageFifo;
    MessageFifo#(8) fromParent <- mkMessageFifo;
    WideMem widemem <- mkWideMemRegFile; // TODO: implement this

    Empty dut <- mkParentProtocolProcessor( toParent, fromParent, widemem );

    function Action checkpoint(Integer i);
        return (action
                    if( debug ) begin
                        $display("Checkpoint %0d", i);
                    end
                endaction);
    endfunction

    function CacheMemReq c2p_upgradeToY(CacheID child, MSI y);
        return CacheMemReq{ child: child, addr: 0, state: y };
    endfunction

    function CacheMemResp c2p_downgradeToY(CacheID child, MSI y, Data d);
        CacheLine line = replicate(0);
        line[0] = d;
        return CacheMemResp{ child: child, addr: 0, state: y, data: line };
    endfunction

    function CacheMemReq p2c_downgradeToY(CacheID child, MSI y);
        return CacheMemReq{ child: child, addr: 0, state: y };
    endfunction

    function CacheMemResp p2c_upgradeToY(CacheID child, MSI y, Data d);
        CacheLine line = replicate(0);
        line[0] = d;
        return CacheMemResp{ child: child, addr: 0, state: y, data: line };
    endfunction

    function Action dequeue( CacheMemMessage m, Bool checkData );
        return (action
                    let incoming = fromParent.first;
                    if( debug ) $display("Dequeuing ", fshow(incoming));
                    case( m ) matches
                        tagged Req .req:
                            begin
                                // waiting for a downgrade request
                                // if we find a response or a wrong request, there was a problem
                                case( incoming ) matches
                                    tagged Req .ireq:
                                        begin
                                            if( req.child == ireq.child && req.addr == ireq.addr && req.state == ireq.state ) begin
                                                // match
                                                fromParent.deq;
                                            end else begin
                                                // mismatch
                                                $fwrite(stderr, "ERROR: incoming request does not match expeted request\n");
                                                $fwrite(stderr, "    expected: ", fshow(req), "\n");
                                                $fwrite(stderr, "    incoming: ", fshow(ireq), "\n");
                                                $finish(1);
                                            end
                                        end
                                    tagged Resp .iresp:
                                        begin
                                            $fwrite(stderr, "ERROR: expected incoming request, found incoming response\n");
                                            $finish(1);
                                        end
                                    default:
                                        begin
                                            $fwrite(stderr, "ERROR: message should be either a Req or a Resp\n");
                                            $finish(1);
                                        end
                                endcase
                            end
                        tagged Resp .resp:
                            begin
                                // waiting for an upgrade response
                                // if we find a wrong response there was a problem
                                case( incoming ) matches
                                    tagged Req .ireq:
                                        begin
                                            // keep waiting, maybe a response will overtake a request
                                            when(False, noAction);
                                        end
                                    tagged Resp .iresp:
                                        begin
                                            if( resp.child == iresp.child && resp.addr == iresp.addr && resp.state == iresp.state && (!checkData || resp.data[0] == iresp.data[0]) ) begin
                                                // match
                                                fromParent.deq;
                                            end else begin
                                                // mismatch
                                                $fwrite(stderr, "ERROR: incoming response does not match expeted response\n");
                                                $fwrite(stderr, "    expected: ", fshow(resp), "\n");
                                                $fwrite(stderr, "    incoming: ", fshow(iresp), "\n");
                                                $finish(1);
                                            end
                                        end
                                    default:
                                        begin
                                            $fwrite(stderr, "ERROR: message should be either a Req or a Resp\n");
                                            $finish(1);
                                        end
                                endcase
                            end
                    endcase
                endaction);
    endfunction


    // This uses StmtFSM to create an FSM for testing
    // See the bluespec reference guide for more info
    Stmt test = (seq
                    // Current state:
                    //  Core 0: I
                    //  Core 1: I

                    // Test 1: core 0 upgrade to S, upgrade to M, downgrade to S, downgrade to I
                    checkpoint(0);
                    toParent.enq_req( c2p_upgradeToY(0, S) );
                    dequeue( tagged Resp p2c_upgradeToY(0, S, 0), False );
                    checkpoint(1);
                    toParent.enq_req( c2p_upgradeToY(0, M) );
                    dequeue( tagged Resp p2c_upgradeToY(0, M, 0), False );
                    checkpoint(2);
                    // This will write 17 to main memory
                    toParent.enq_resp( c2p_downgradeToY(0, S, 17) );
                    checkpoint(3);
                    // This should not write to main memory
                    toParent.enq_resp( c2p_downgradeToY(0, I, 8) );

                    // Current state:
                    //  Core 0: I
                    //  Core 1: I

                    // Test 2: core 1 upgrade to M, check data from previous downgrade responses
                    checkpoint(4);
                    toParent.enq_req( c2p_upgradeToY(1, M) );
                    // Make sure the data in the upgrade response is 17
                    dequeue( tagged Resp p2c_upgradeToY(1, M, 17), True );

                    // Current state:
                    //  Core 0: I
                    //  Core 1: M

                    // Test 3: core 0 upgrade to S while other core is in M
                    checkpoint(5);
                    toParent.enq_req( c2p_upgradeToY(0, S) );
                    // cache 1 is in M, so it will need to downgrade
                    dequeue( tagged Req p2c_downgradeToY(1, S), False );
                    checkpoint(6);
                    // 22 will get written to main memory
                    toParent.enq_resp( c2p_downgradeToY(1, S, 22) );
                    // now cache 0 can get upgraded to Y
                    dequeue( tagged Resp p2c_upgradeToY(0, S, 22), True );

                    // Current state:
                    //  Core 0: S
                    //  Core 1: S

                    // Test 4: core 0 upgrade S to M
                    checkpoint(7);
                    toParent.enq_req( c2p_upgradeToY(0, M) );
                    dequeue( tagged Req p2c_downgradeToY(1, I), False );
                    checkpoint(8);
                    toParent.enq_resp( c2p_downgradeToY(1, I, 0) );
                    dequeue( tagged Resp p2c_upgradeToY(0, M, 0), False );

                    // Current state:
                    //  Core 0: M
                    //  Core 1: I

                    // Test 5: voluntary downgrade
                    checkpoint(9);
                    // 200 will get written to main memory
                    toParent.enq_resp( c2p_downgradeToY(0, I, 200) );

                    // Current state:
                    //  Core 0: I
                    //  Core 1: I

                    // Test 6: both upgrade to S
                    checkpoint(10);
                    toParent.enq_req( c2p_upgradeToY(0, S) );
                    toParent.enq_req( c2p_upgradeToY(1, S) );
                    checkpoint(11);
                    // in a more complicated implementation, these two could be reordered
                    dequeue( tagged Resp p2c_upgradeToY(0, S, 200), True );
                    dequeue( tagged Resp p2c_upgradeToY(1, S, 200), True );

                    // Current state:
                    //  Core 0: S
                    //  Core 1: S

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
                            if(!debug) $fwrite(stderr, "Set debug to true in mkCacheParentTest and recompile to get more info\n");
                        endaction);
                        $finish(1);
                    endseq);
    mkAutoFSM(timeout);
endmodule
