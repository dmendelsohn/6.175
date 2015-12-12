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
module mkNBCacheTest(Empty);
    // Set this to true to see more messages displayed to stdout
    Bool debug = True;

    MessageFifo#(8) parentToCache <- mkMessageFifo;
    MessageFifo#(8) cacheToParent <- mkMessageFifo;

    NBCache nbcache <- mkNBCache( 0, parentToCache, cacheToParent );

    function Action checkpoint(Integer i);
        return (action
                    if( debug ) begin
                        $display("Checkpoint %0d", i);
                    end
                endaction);
    endfunction

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

    function Action getCacheResp( NBCacheToken token, Data data );
        return (action
                    let resp <- nbcache.resp;
                    if( resp.token != token || resp.data != data ) begin
                        // no match!
                        $fwrite(stderr, "ERROR : NBCacheTest : got response (%0d, 0x%0x), expected response (%0d, 0x%0x)\n", resp.token, resp.data, token, data);
                    end
                endaction);
    endfunction

    function Action reqCacheLd( NBCacheToken token, Addr a );
        return (action
                    nbcache.req( NBCacheReq{ addr: a, data: 0, op: Ld, token: token } );
                endaction);
    endfunction

    function Action reqCacheSt( Addr a, Data d );
        return (action
                    nbcache.req( NBCacheReq{ addr: a, data: d, op: St, token: 0 } );
                endaction);
    endfunction

    function Action deqCheckCacheToParent( CacheMemMessage m, Bool checkData );
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
    Stmt test1 = (seq
                    // Test 1: multiple requests in flight
                    $display("Test 1: Multiple requests in flight");
                    checkpoint(0);
                    reqCacheLd( 1, address(0, 0, 0) );
                    checkpoint(1);
                    reqCacheLd( 2, address(0, 1, 0) );
                    checkpoint(3);
                    reqCacheLd( 3, address(0, 2, 0) );
                    checkpoint(4);
                    reqCacheLd( 4, address(0, 3, 0) );

                    checkpoint(5);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,0,0), S ), False );
                    checkpoint(6);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,1,0), S ), False );
                    checkpoint(7);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,2,0), S ), False );
                    checkpoint(8);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,3,0), S ), False );

                    checkpoint(9);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), S, 0 ) );
                    getCacheResp( 1, 0 );

                    checkpoint(10);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,1,0), S, 17 ) );
                    getCacheResp( 2, 17 );

                    checkpoint(11);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,3,0), S, 25 ) );
                    getCacheResp( 4, 25 );

                    checkpoint(12);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,2,0), S, 55 ) );
                    getCacheResp( 3, 55 );

                    // clear cache
                    checkpoint(13);
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), I ) );
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY(   address(0,0,0), I, 0 ), False );
                    parentToCache.enq_req( p2c_downgradeToY( address(0,1,0), I ) );
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY(   address(0,1,0), I, 0 ), False );
                    parentToCache.enq_req( p2c_downgradeToY( address(0,2,0), I ) );
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY(   address(0,2,0), I, 0 ), False );
                    parentToCache.enq_req( p2c_downgradeToY( address(0,3,0), I ) );
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY(   address(0,3,0), I, 0 ), False );
                    $display("PASSED\n");
                endseq);

    Stmt test2 = (seq
                    // Test 2: same cache line, different offset
                    $display("Test 2: Same cache line, different offsets");
                    checkpoint(0);
                    reqCacheLd( 1, address(0, 0, 0) );
                    checkpoint(1);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,0,0), S ), False );
                    checkpoint(2);
                    reqCacheLd( 2, address(0, 0, 1) );

                    // Respond to first request and get responses from the previous loads
                    checkpoint(3);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), S, 15 ) );
                    checkpoint(4);
                    getCacheResp(1, 15);
                    checkpoint(5);
                    getCacheResp(2, 0);

                    // two load hits
                    checkpoint(6);
                    reqCacheLd( 3, address(0, 0, 2) );
                    checkpoint(7);
                    getCacheResp(3, 0);
                    checkpoint(8);
                    reqCacheLd( 4, address(0, 0, 3) );
                    checkpoint(9);
                    getCacheResp(4, 0);

                    // There should be nothing else in the cacheToParent fifo
                    checkpoint(10);
                    action
                        if( cacheToParent.notEmpty == True ) begin
                            $fwrite(stderr, "ERROR: \n");
                            $finish(1);
                        end
                    endaction

                    checkpoint(11);
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), I ) );
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY(   address(0,0,0), I, 0 ), False );
                    $display("PASSED\n");
                endseq);

    Stmt test3 = (seq
                    // Test 3: Same index, Different tag
                    $display("Test 3: Same index, different tag");
                    checkpoint(0);
                    reqCacheLd( 1, address(0,0,0) );
                    checkpoint(1);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,0,0), S ), False );
                    checkpoint(2);
                    // This won't be able to send a request
                    reqCacheLd( 2, address(1,0,0) );
                    checkpoint(3);
                    delay(10);
                    checkpoint(4);
                    // make sure it didn't send a request
                    action
                        if( cacheToParent.notEmpty == True ) begin
                            $fwrite(stderr, "ERROR: \n");
                            $finish(1);
                        end
                    endaction

                    // send the response for the first load request
                    checkpoint(5);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), S, 99 ) );
                    // This will return a response ...
                    checkpoint(6);
                    getCacheResp(1, 99);
                    // ... send a downgrade response ...
                    checkpoint(7);
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY( address(0,0,0), I, 0 ), False );
                    // ... and send an upgrade request
                    checkpoint(8);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(1,0,0), S ), False );

                    // send the response for the second load request ...
                    checkpoint(9);
                    parentToCache.enq_resp( p2c_upgradeToY( address(1,0,0), S, 88 ) );
                    // ... and get the response
                    checkpoint(10);
                    getCacheResp(2, 88);

                    // clear the cache
                    checkpoint(11);
                    parentToCache.enq_req( p2c_downgradeToY( address(1,0,0), I ) );
                    checkpoint(12);
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY( address(1,0,0), I, 0 ), False );
                    $display("PASSED\n");
                endseq);

    Stmt test4 = (seq
                    // Test 4: Stores
                    $display("Test 4: Stores");

                    // request a store
                    checkpoint(0);
                    reqCacheSt( address(0,0,0), 25 );
                    checkpoint(1);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,0,0), M ), False );

                    // request another store to the same line
                    checkpoint(2);
                    reqCacheSt( address(0,0,1), 15 );

                    // make sure it didn't send a request
                    checkpoint(3);
                    delay(10);
                    action
                        if( cacheToParent.notEmpty == True ) begin
                            $fwrite(stderr, "ERROR: \n");
                            $finish(1);
                        end
                    endaction

                    // send the cache line to the processor
                    checkpoint(4);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), M, 82 ) );
                    // send another st request
                    checkpoint(5);
                    reqCacheSt( address(0,0,2), 5 );

                    // wait and send another
                    checkpoint(6);
                    delay(10);
                    reqCacheSt( address(0,0,3), 55 );

                    // sned a downgrade request to see written data
                    checkpoint(7);
                    delay(10);
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), S ) );
                    checkpoint(8);
                    action
                        CacheLine l = replicate(0);
                        l[0] = 25;
                        l[1] = 15;
                        l[2] = 5;
                        l[3] = 55;
                        if( cacheToParent.first matches tagged Resp .resp ) begin
                            if( resp.data != l ) begin
                                $display("resp.data = %x", resp.data);
                                $display("l = %x", l);
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

                    // clear the cache
                    checkpoint(9);
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), I ) );
                    checkpoint(10);
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY( address(0,0,0), I, 0 ), False );
                    $display("PASSED\n");
                endseq);

    Stmt test5 = (seq
                    // Test 5: Store bypassing
                    $display("Test 5: Store bypassing");
                    checkpoint(0);
                    reqCacheLd( 1, address(0,0,0) );
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,0,0), S ), False );
                    checkpoint(1);
                    reqCacheSt( address(0,0,0), 39 );
                    checkpoint(2);
                    reqCacheSt( address(0,0,0), 51 );
                    checkpoint(3);
                    reqCacheLd( 2, address(0,0,0) );
                    checkpoint(4);
                    // Ld hit from store queue
                    getCacheResp( 2, 51 );
                    checkpoint(5);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), S, 99 ) );
                    checkpoint(6);
                    getCacheResp( 1, 99 );
                    checkpoint(7);
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,0,0), M ), False );
                    checkpoint(8);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), M, 0 ) );
                    // The two stores should hit now
                    checkpoint(9);
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), I) );
                    checkpoint(10);
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY( address(0,0,0), I, 51 ), True );
                    $display("PASSED\n");
                endseq);

    Stmt test6 = (seq
                    // Test 6: Resending requests
                    $display("Test 6: Resending requests");
                    checkpoint(0);
                    reqCacheSt( address(0,1,0), 33 );
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,1,0), M ), False );
                    checkpoint(1);
                    reqCacheSt( address(0,0,0), 55 );
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,0,0), M ), False );
                    checkpoint(2);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), M, 22 ) );
                    checkpoint(3);
                    reqCacheLd( 1, address(1,0,0) );
                    // downgrade response
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY( address(0,0,0), I, 22 ), True );
                    // upgrade request
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(1,0,0), S ), False );

                    // (0,1,0) resp
                    checkpoint(4);
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,1,0), M, 11 ) );

                    // Store to (0,1,0) should commit
                    checkpoint(5);
                    parentToCache.enq_resp( p2c_upgradeToY( address(1,0,0), S, 33 ) );

                    // ld hit
                    checkpoint(6);
                    getCacheResp(1, 33);

                    checkpoint(7);
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY( address(1,0,0), I, 0 ), False );
                    deqCheckCacheToParent( tagged Req c2p_upgradeToY( address(0,0,0), M ), False );
                    parentToCache.enq_resp( p2c_upgradeToY( address(0,0,0), M, 22 ) );

                    // Store to (0,0,0) should commit

                    // now check the results with evictions
                    parentToCache.enq_req( p2c_downgradeToY( address(0,0,0), I ) );
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY( address(0,0,0), I, 55 ), True );

                    parentToCache.enq_req( p2c_downgradeToY( address(0,1,0), I ) );
                    deqCheckCacheToParent( tagged Resp c2p_downgradeToY( address(0,1,0), I, 33 ), True );
                    $display("PASSED\n");
                endseq);

    Stmt test = (seq
                    test1;
                    test2;
                    test3;
                    test4;
                    test5;
                    test6;
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
                            if(!debug) $fwrite(stderr, "Set debug to true in mkNBCacheTest and recompile to get more info\n");
                        endaction);
                        $finish(1);
                    endseq);
    mkAutoFSM(timeout);
endmodule
