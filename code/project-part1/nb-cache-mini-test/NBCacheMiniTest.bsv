import RegFile::*;
import StmtFSM::*;
import Vector::*;

import Fifo::*;
import Types::*;
import MemTypes::*;
import CacheTypes::*;
import NBCacheTypes::*;

import MessageFifo::*;
import ParentProtocolProcessor::*;
import NBCache::*;


(* synthesize *)
module mkNBCacheMiniTest(Empty);
    MessageFifo#(8) parentToCache <- mkMessageFifo;
    MessageFifo#(8) cacheToParent <- mkMessageFifo;

    NBCache nbcache <- mkNBCache( 0, parentToCache, cacheToParent );

    function Addr address( CacheTag tag, CacheIndex index, CacheOffset offset );
        return {tag, index, offset, 0};
    endfunction

    function CacheMemReq c2p_upgradeToY(Addr a, MSI y);
        return CacheMemReq{ child: 0, addr: a, state: y };
    endfunction

    function CacheMemResp c2p_downgradeToY(Addr a, MSI y, Data d);
        CacheLine line = replicate(0);
        line[0] = d;
        return CacheMemResp{ child: 0, addr: a, state: y, data: line };
    endfunction

    function CacheMemReq p2c_downgradeToY(Addr a, MSI y);
        return CacheMemReq{ child: 0, addr: a, state: y };
    endfunction

    function CacheMemResp p2c_upgradeToY(Addr a, MSI y, Data d);
        CacheLine line = replicate(0);
        line[0] = d;
        return CacheMemResp{ child: 0, addr: a, state: y, data: line };
    endfunction

    function Action getResp( NBCacheToken token, Data data );
        return (action
                    let resp <- nbcache.resp;
                    if( resp.token != token || resp.data != data ) begin
                        // no match!
                        $fwrite(stderr, "ERROR : NBCacheTest : got response (%0d, 0x%0x), expected response (%0d, 0x%0x)\n", resp.token, resp.data, token, data);
                    end
                endaction);
    endfunction

    function Action reqLd( NBCacheToken token, Addr a );
        return (action
                    nbcache.req( NBCacheReq{ addr: a, data: 0, op: Ld, token: token } );
                endaction);
    endfunction

    function Action reqSt( Addr a, Data d );
        return (action
                    nbcache.req( NBCacheReq{ addr: a, data: d, op: St, token: 0 } );
                endaction);
    endfunction

    function Action dequeue( CacheMemMessage m, Bool checkData );
        return (action
                    let incoming = cacheToParent.first;
                    case( m ) matches
                        tagged Req .req:
                            begin
                                // waiting for a downgrade request
                                // if we find a response or a wrong request, there was a problem
                                case( incoming ) matches
                                    tagged Req .ireq:
                                        begin
                                            if( req.child == ireq.child
                                                    && getTag(req.addr) == getTag(ireq.addr)
                                                    && getIndex(req.addr) == getIndex(ireq.addr)
                                                    && req.state == ireq.state ) begin
                                                // match
                                                cacheToParent.deq;
                                            end else begin
                                                // mismatch
                                                $fwrite(stderr, "ERROR : NBCacheTest : incoming request does not match expeted request\n");
                                                $fwrite(stderr, "    expected: ", fshow(req), "\n");
                                                $fwrite(stderr, "    incoming: ", fshow(ireq), "\n");
                                                $finish(1);
                                            end
                                        end
                                    tagged Resp .iresp:
                                        begin
                                            $fwrite(stderr, "ERROR : NBCacheTest : expected incoming request, found incoming response\n");
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
                                            if( resp.child == iresp.child
                                                    && getTag(resp.addr) == getTag(iresp.addr)
                                                    && getIndex(resp.addr) == getIndex(iresp.addr)
                                                    && resp.state == iresp.state
                                                    && (!checkData || resp.data[0] == iresp.data[0]) ) begin
                                                // match
                                                cacheToParent.deq;
                                            end else begin
                                                // mismatch
                                                $fwrite(stderr, "ERROR : NBCacheTest : incoming response does not match expeted response\n");
                                                $fwrite(stderr, "    expected: ", fshow(resp), "\n");
                                                $fwrite(stderr, "    incoming: ", fshow(iresp), "\n");
                                                $finish(1);
                                            end
                                        end
                                endcase
                            end
                    endcase
                endaction);
    endfunction


    // This uses StmtFSM to create an FSM for testing
    // See the bluespec reference guide for more info
    Stmt load_mini_tests =
                (seq
                    $display("Load mini test 1: load miss");
                    $display("  Requesting load from cache");
                    reqLd( 1, address(0,0,0) );
                    $display("  Looking for upgrade to S request to main memory");
                    dequeue( tagged Req c2p_upgradeToY( address(0,0,0), S ), False );
                    $display("  Found upgrade to S request, sending upgrade to S response");
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), S, 10 ) );
                    $display("  Looking for response from load");
                    getResp(1, 10);
                    $display("  Found response, test passed\n");

                    $display("Load mini test 2: load hit");
                    $display("  Requesting load from cache");
                    reqLd( 1, address(0,0,0) );
                    $display("  Looking for response from load");
                    getResp(1, 10);
                    $display("  Found response, test passed\n");
                endseq);

    Stmt store_mini_tests =
                (seq
                    $display("Store mini test 1: store miss (S -> M)");
                    $display("  Requesting store from cache");
                    reqSt( address(0,0,0), 500 );
                    $display("  Looking for upgrade to M request to main memory");
                    dequeue( tagged Req c2p_upgradeToY( address(0,0,0), M ), False );
                    $display("  Found upgrade to M request, sending upgrade to M response");
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), M, 0 ) );
                    $display("  Sending downgrade to I request to check data");
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), I ) );
                    $display("  Looking for downgrade response");
                    dequeue( tagged Resp c2p_downgradeToY( address(0,0,0), I, 500), True );
                    $display("  Found correct data, test passed\n");

                    $display("Store mini test 2: store miss (I -> M)");
                    $display("  Requesting store from cache");
                    reqSt( address(0,0,1), 400 );
                    $display("  Looking for upgrade to M request to main memory");
                    dequeue( tagged Req c2p_upgradeToY( address(0,0,0), M ), False );
                    $display("  Found upgrade to M request, sending upgrade to M response");
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), M, 0 ) );
                    $display("  Data will be checked in the next test\n");

                    $display("Store mini test 3: store hit");
                    $display("  Requesting store from cache");
                    reqSt( address(0,0,0), 300 );
                    delay(5); // delay to make sure store happens
                    $display("  Sending downgrade to I request to check data");
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), I ) );
                    $display("  Looking for downgrade response");
                    action
                        CacheLine l = replicate(0);
                        l[0] = 300;
                        l[1] = 400;
                        if( cacheToParent.first matches tagged Resp .resp ) begin
                            if( resp.data != l ) begin
                                $display("resp.data = %x", resp.data);
                                $fwrite(stderr, "ERROR: Unexpected data in downgrade response\n");
                                $finish(1);
                            end else begin
                                cacheToParent.deq;
                            end
                        end else begin
                            $fwrite(stderr, "ERROR: Expected downgrade response in parentToCache, but found an upgrade request\n");
                            $finish(1);
                        end
                    endaction
                    $display("  Data matches, test passed\n");
                endseq);

    Stmt other_mini_tests =
                (seq
                    $display("Additional mini test: rule 7");
                    $display("  Getting cache line (0,0)");
                    reqLd( 1, address(0,0,0) );
                    dequeue( tagged Req c2p_upgradeToY( address(0,0,0), S ), False );
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), S, 77 ) );
                    getResp( 1, 77 );
                    $display("  Getting cache line (1,0), evecting (0,0) first");
                    reqLd( 2, address(1,0,0) );
                    dequeue( tagged Resp c2p_downgradeToY( address(0,0,0), I, 0 ), False );
                    $display("  Cache send downgrade response, sending downgrade request to cache, cache should ignore it");
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), I ) );
                    $display("  Make sure the cache didn't send another response");
                    action
                        if( cacheToParent.hasResp == True ) begin
                            $fwrite(stderr, "ERROR: Cache sent another response\n");
                            $finish(1);
                        end
                    endaction
                    $display("  No response sent, finishing test");
                    dequeue( tagged Req c2p_upgradeToY( address(1,0,0), S ), False );
                    parentToCache.enq_resp( p2c_upgradeToY( address(1,0,0), S, 88 ) );
                    getResp( 2, 88 );
                    $display("  Test passed\n");
                endseq);

    Stmt test = (seq
                    load_mini_tests;
                    store_mini_tests;
                    other_mini_tests;
                    $display("All tests PASSED");
                    $finish(0);
                endseq);
    mkAutoFSM(test);

    // Timeout FSM
    // If the test doesn't finish in 10000 cycles, this prints an error
    Stmt timeout = (seq
                        delay(10000);
                        (action
                            $fwrite(stderr, "ERROR: Testbench stalled.\n");
                        endaction);
                        $finish(1);
                    endseq);
    mkAutoFSM(timeout);
endmodule
