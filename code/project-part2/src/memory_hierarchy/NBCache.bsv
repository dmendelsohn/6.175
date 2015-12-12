import Vector::*;
import RegFile::*;

import Types::*;
import ProcTypes::*;
import MemTypes::*;
import CacheTypes::*;
import NBCacheTypes::*;

import Fifo::*;
import MessageFifo::*;
import StQ::*;
import LdBuff::*;

typedef enum {Ready, LdHitState, StHitState, StReqState, LdReqState} NBCacheState deriving (Bits, Eq);

module mkNBCache(CacheID cache_id, MessageFifo#(n) parentToCache, MessageFifo#(n) cacheToParent, NBCache ifc);
    Vector#(CacheRows, Reg#(CacheLine)) dataArray <- replicateM(mkReg(unpack(0)));
    Vector#(CacheRows, Reg#(CacheTag)) tagArray <- replicateM(mkReg(unpack(0)));
    Vector#(CacheRows, Reg#(Maybe#(MSI))) waitp <- replicateM(mkReg(tagged Invalid));
    Vector#(CacheRows, Reg#(MSI)) stateArray <- replicateM(mkReg(I));
    StQ#(StQSz) stQ <- mkStQ;
    LdBuff#(LdBuffSz) ldBuff <- mkLdBuff;
    Reg#(NBCacheState) status <- mkReg(Ready);
    Reg#(CacheMemResp) memRespHolder <- mkReg(unpack(0));
    Reg#(Maybe#(Addr)) link <- mkReg(tagged Invalid);
    Fifo#(2, NBCacheResp)       hitQ     <- mkBypassFifo;

    function Action invalidateLinkRegister(Addr addr); return (action
      if (isValid(link) && getTag(addr) == getTag(fromMaybe(?,link)) &&
      getIndex(addr) == getIndex(fromMaybe(?,link))) begin
        $display("=====================================");
        $display("actually invalidating link register");
        $display("=====================================");
        link <= tagged Invalid;
      end else begin
        $display("link valid? %b", isValid(link));
        $display("addr index, tag= %x, %x", getIndex(addr), getTag(addr));
        $display("link addr index, tag = %x, %x", getIndex(fromMaybe(?,link)), getTag(fromMaybe(?,link)));
      end
    endaction); endfunction

    function Addr constructAddr(CacheIndex index, CacheTag tag);
      Addr addr = zeroExtend(tag);
      addr = (addr << (valueOf(AddrSize) - valueOf(CacheTagSz)));
      Addr indexMask = zeroExtend(index);
      indexMask = (indexMask << (2 + valueOf(TLog#(CacheLineWords))));
      return (addr | indexMask);
    endfunction

    function Bool can_send_upgrade_req( Addr a, MSI y );
    // Returns true if the cache can send an upgrade to y request for address a.
    // If a downgrade response is necessary, this includes if that downgrade is possible too.
      let curIndex = getIndex(a);
      let curTag = getTag(a);

      //check that we aren't currently waiting on a previous request
      //if:
      //different tag in cache line
      //need to see if we can send downgrade response
      //then:
      //can send both upgrade request and downgrade response
      //rule 1 & rule 8
      //or:
      //same tag
      //check that current cacheline state is lower than upgrade request y
      //then rule 1 possible

      return ( !isValid(waitp[curIndex]) && (curTag != tagArray[curIndex] || stateArray[curIndex] < y));
    endfunction

    function Action send_upgrade_req( Addr a, MSI y ); return (action
    // If rule 8 is necessary, this sends an downgrade response for the old cache line
    // In all cases, this sends an upgrade request for the new cache line or for the new state
      let curIndex = getIndex(a);
      let curTag = getTag(a);

      //different tag in cache line
      //send downgrade response
      //do rule 8
      if ( curTag != tagArray[curIndex] && stateArray[curIndex] != I) begin
        //constructAddr func not tested
        $display("===========================");
        $display("rule 8 sending response");
        let oldAddr = constructAddr(curIndex, tagArray[curIndex]);
        $display("oldAddr: %x", oldAddr);
        $display("cache_id: %x", cache_id);
        CacheMemResp resp = CacheMemResp{addr: oldAddr, child: cache_id, state: I, data: dataArray[curIndex]};
        cacheToParent.enq_resp(resp);
        tagArray[curIndex] <= curTag;
        //make state invalid while we wait for response
        stateArray[curIndex] <= I;
        //invalidate link register if necessary
        $display("invalidating link register on rule 8 downgrade");
        invalidateLinkRegister(oldAddr);
        $display("===========================");
      end
      waitp[curIndex] <= tagged Valid y;

      //do rule 1
      CacheMemReq req = CacheMemReq{addr: a, child: cache_id, state: y};
      cacheToParent.enq_req(req);

    endaction); endfunction

	function Action returnData(NBCacheToken token, Data data); return (action
	//Puts stuff in the respQ
		hitQ.enq(NBCacheResp{data: data, token: token});
	endaction); endfunction

	function Action sc_success_return(NBCacheToken token); return (action
	//Puts stuff in the respQ
		hitQ.enq(NBCacheResp{data: 1, token: token});
	endaction); endfunction

	function Action sc_fail_return(NBCacheToken token); return (action
	//Puts stuff in the respQ
		hitQ.enq(NBCacheResp{data: 0, token: token});
	endaction); endfunction

	rule processMemMessage(status == Ready);
		CacheMemMessage m = parentToCache.first; // type is CacheMemMessage
		case (m) matches
			tagged Resp .resp:
			begin
				let addr = resp.addr;
				let tag = getTag(addr);
				let index = getIndex(addr);
				let line = resp.data;
				let state = resp.state;
        $display("============================");
        $display("nbcache receive response:");
        $display("addr: %x", addr);
        $display("tag: %x", tag);
        $display("index: %x", index);
        $display("data: %x", line);
        $display("state =", fshow(state));
        $display("============================");
        //possible change: checking waitp instead of state array
        if (stateArray[index] == I) begin
          dataArray[index] <= line;
          if (line == unpack(0)) $display("writing zero data");
        end
				stateArray[index] <= state;
				tagArray[index] <= tag;
        waitp[index] <= tagged Invalid;
				memRespHolder <= resp;
				status <= LdHitState;
		    parentToCache.deq;
			end
			tagged Req .req:
			begin
				// Process and respond to downgrade request
				let addr = req.addr;
				let tag = getTag(addr);
				let index = getIndex(addr);
				let state = req.state;
        $display("============================");
        $display("nbcache receive request:");
        $display("addr: %x", addr);
        $display("tag: %x", tag);
        $display("index: %x", index);
        $display("state =", fshow(state));
        parentToCache.deq;
        //Added this line so we don't do anything if our line is a different tag
        // or is already in a lower state (rule 7)
        if ( stateArray[index] > state && tagArray[index] == tag ) begin
          //possible change: setting the line every time
          CacheLine line = unpack(0);
          if (stateArray[index] == M) begin
            line = dataArray[index];
          end
          //changed this to enq_resp
          cacheToParent.enq_resp(CacheMemResp{child: cache_id, addr: addr, state: state, data: line});
          stateArray[index] <= state;
          //Check and Invalidate link register
          if (state == I) begin
            $display("invalidating register on invalid cache eviction");
            invalidateLinkRegister(addr);
          end
        end //we're already either downgraded or invalid with a different tag
        $display("============================");
      end
		endcase
	endrule


	rule processLdHitState(status == LdHitState);
		let resp = memRespHolder;
		let addr = resp.addr;
		let offset = getOffset(addr);
		let line = resp.data;
		let state = resp.state;
		let ldBuffSearch = ldBuff.searchHit(addr);
    $display("============================");
    $display("nbcache LdHitState:");
    $display("addr: %x", addr);
    $display("data: %x", line);
    $display("state =", fshow(state));
    $display("ldBuffSearch valid? %b", isValid(ldBuffSearch));
		if (isValid(ldBuffSearch)) begin // hit!

			let bufferIndex = tpl_1(validValue(ldBuffSearch));
			let ldBuffData = tpl_2(validValue(ldBuffSearch));
      $display("offset: %x", getOffset(ldBuffData.addr));
      $display("============================");

			ldBuff.remove(bufferIndex);
      if (ldBuffData.op == Ll) link <= tagged Valid addr;
			returnData(ldBuffData.token, line[getOffset(ldBuffData.addr)]);
      //Removed return to Ready state so it keeps taking requests off the ldBf
		end else begin
      $display("no offset");
      $display("============================");
			status <= StHitState;
		end
	endrule

	rule processStHitState(status == StHitState);
    $display("============================");
    $display("nbcache StHitState:");
    if (!stQ.empty) begin
      $display("stQ not empty");
      StQData stQHead = stQ.first;
      let index = getIndex(stQHead.addr);
      let offset = getOffset(stQHead.addr);
      let tag = getTag(stQHead.addr);
      Bool stQHit = (stateArray[index] == M && tagArray[index] == tag);
      if (stQHit) begin  //hit at head of store queue!
        //store conditional failure
        $display("testing Sc link valid:");
        $display("isValid(link)? %b", isValid(link));
        $display("link addr? %x", fromMaybe(?,link));
        $display("addr = %x", stQHead.addr);
        if (stQHead.op == Sc && (!isValid(link) || (stQHead.addr != fromMaybe(?,link)))) begin
          sc_fail_return(stQHead.token);
        end else begin
          stQ.deq;
          let line = dataArray[index];
          $display("stQ hit");
          $display("stQ data = %x", stQHead.data);
          $display("storing into line = %x", line);
          line[offset] = stQHead.data;
          dataArray[index] <= line;
          //send store conditional success
          if ( stQHead.op == Sc ) sc_success_return(stQHead.token);
        end
      //Removed return to Ready state so it keeps taking requests off the stQ
		  end else begin
        $display("stQ miss");
			  status <= StReqState;
      end
    end else begin
      $display("stQ empty");
      status <= LdReqState;
    end
    $display("============================");
	endrule

	rule processStReqState(status == StReqState);
    //Changed from memRespHolder to StQHead
		StQData stQHead = stQ.first;
		Addr reqAddr = stQHead.addr;
    $display("============================");
    $display("nbcache StReqState:");
    $display("reqAddr: %x", reqAddr);
		if (can_send_upgrade_req(reqAddr, M) ) begin
      $display("sending upgrade request");
			send_upgrade_req(reqAddr, M);
    end else begin
      $display("not sending upgrade request");
      $display("reason: ");

      let curIndex = getIndex(reqAddr);
      let curTag = getTag(reqAddr);
      if (isValid(waitp[curIndex])) begin

        $display("current waiting on =",
        fshow(validValue(waitp[curIndex])));
      end
      if (curTag == tagArray[curIndex] && stateArray[curIndex] == M) begin
        $display("tags match and current state equal to upgrade req state");
      end
    end
    $display("============================");
		status <= LdReqState;
	endrule

	rule processLdReqState(status == LdReqState);
		let ldBuffConflict = ldBuff.searchConflict(memRespHolder.addr);
    $display("============================");
    $display("nbcache LdReqState:");
    $display("ldBuffConflict valid?: %b", isValid(ldBuffConflict));
		if (isValid(ldBuffConflict)) begin
			Addr reqAddr = validValue(ldBuffConflict).addr;
			MSI reqState = S; //Not sure about this
			if (can_send_upgrade_req(reqAddr, reqState) ) begin
				send_upgrade_req(reqAddr, reqState);
      end else begin
        $display("not sending upgrade request");
        $display("reason: ");
        let curIndex = getIndex(reqAddr);
        let curTag = getTag(reqAddr);
        if (isValid(waitp[curIndex])) begin
          $display("current waiting on =",
          fshow(validValue(waitp[curIndex])));
        end
        if (curTag == tagArray[curIndex] && stateArray[curIndex] >=
          reqState) begin
          $display("tags match and current state equal to upgrade req state");
          $display("current state = ", fshow(stateArray[curIndex]));
          $display("req state = ", fshow(reqState));
        end
      end
		end
    $display("============================");
		status <= Ready;
	endrule

  method Action req(NBCacheReq r) if (status == Ready);
		let addr = r.addr;
		let tag = getTag(addr);
		let index = getIndex(addr);
		let offset = getOffset(addr);
		let data = r.data;
		let op = r.op;
		let token = r.token;
    $display("============================");
    $display("nbcache req method:");
    $display("addr: %x", addr);
    $display("tag: %x", tag);
    $display("offset: %x", offset);
    $display("index: %x", index);
    $display("data: %x", data);
    $display("op = ", fshow(op));
    $display("token = %x", token);
    $display("current data line = %x", dataArray[index]);
		if (op == Ld || op == Ll) begin
			Maybe#(Data) fromStQ = stQ.search(addr);
			if (isValid(fromStQ)) begin
        $display("stQ is Valid");
				let d = validValue(fromStQ);
        if (op == Ll) link <= tagged Valid addr;
				returnData(token, d);
			end else begin // Check cache
				Bool cacheHit = (stateArray[index] > I && tagArray[index] == tag);
        $display("stQ not Valid");
				if (cacheHit) begin
          $display("cache hit");
					let d = dataArray[index][offset];
          if (op == Ll) link <= tagged Valid addr;
					returnData(token, d);
				end else begin // Insert into load buffer, send upgrade request if necessary & possible
          $display("cache miss");
					ldBuff.enq(LdBuffData{addr: addr, op: op, token: token});
					if (can_send_upgrade_req(addr, S) ) begin
            $display("send upgrade request");

						send_upgrade_req(addr, S);
          end else begin
            $display("can't send upgrade request");
            $display("reason: ");
            let curIndex = getIndex(addr);
            let curTag = getTag(addr);
            if (isValid(waitp[curIndex])) begin
              $display("current waiting on =",
              fshow(validValue(waitp[curIndex])));
            end
            if (curTag == tagArray[curIndex] && (stateArray[curIndex] ==
              S || stateArray[curIndex] == M)) begin
              $display("tags match and current state equal to upgrade req state");
            end
          end
				end
			end
		end else begin //Store
      //send store conditional fail
      $display("testing Sc link valid:");
      $display("isValid(link)? %b", isValid(link));
      $display("link addr? %x", fromMaybe(?,link));
      $display("addr = %x", addr);
      if (op == Sc && (!isValid(link) || (addr != fromMaybe(?,link)))) begin
        sc_fail_return(token);
      end else if (stQ.empty && stateArray[index] == M && tagArray[index] == tag) begin //Store hit
        $display("store hit");
        $display("storing offset %x", data);
				let line = dataArray[index];
        $display("into line %x", line);
				line[offset] = data;
				dataArray[index] <= line;
        //send store conditional success
        if ( op == Sc ) sc_success_return(token);
			end else begin //Store miss
        $display("store miss");
				stQ.enq(StQData{addr: addr, data: data, op: op, token: token});

				if (can_send_upgrade_req(addr, M) ) begin
          $display("send upgrade request");
					send_upgrade_req(addr, M);
        end else begin
          $display("can't send upgrade request");
          $display("reason: ");
          let curIndex = getIndex(addr);
          let curTag = getTag(addr);
          if (isValid(waitp[curIndex])) begin
            $display("current waiting on =",
            fshow(validValue(waitp[curIndex])));
          end
          if (curTag == tagArray[curIndex] && stateArray[curIndex] == M) begin
            $display("tags match and current state equal to upgrade req state");
          end
        end
      end
		end
    $display("============================");

	endmethod

  method ActionValue#(NBCacheResp) resp;
    $display("============================");
    $display("nbcache resp method:");
    $display("============================");
		hitQ.deq;
	  return hitQ.first;
	endmethod
endmodule
