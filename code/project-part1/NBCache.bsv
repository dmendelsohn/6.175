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
    Vector#(CacheRows, Reg#(CacheLine)) dataArray <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(CacheTag)) tagArray <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(Maybe#(MSI))) waitp <- replicateM(mkReg(tagged Invalid));
    Vector#(CacheRows, Reg#(MSI)) stateArray <- replicateM(mkReg(I));
    StQ#(StQSz) stQ <- mkStQ;
    LdBuff#(LdBuffSz) ldBuff <- mkLdBuff;
    Reg#(NBCacheState) status <- mkReg(Ready);
    Reg#(CacheMemResp) memRespHolder <- mkRegU;
    Fifo#(2, NBCacheResp)       hitQ     <- mkBypassFifo;

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
        let oldAddr = constructAddr(curIndex, tagArray[curIndex]);
        CacheMemResp resp = CacheMemResp{addr: oldAddr, child: cache_id, state: I, data: dataArray[curIndex]};
        cacheToParent.enq_resp(resp);
        tagArray[curIndex] <= curTag;
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
				stateArray[index] <= state;
				tagArray[index] <= tag;
				dataArray[index] <= line;
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
        parentToCache.deq;
        //Added this line so we don't do anything if our line is a different tag
        // or is already in a lower state (rule 7)
        if ( stateArray[index] > state && tagArray[index] == tag ) begin
          CacheLine line = unpack(0);
          if (stateArray[index] == M) begin
            line = dataArray[index];
          end
          //changed this to enq_resp
          cacheToParent.enq_resp(CacheMemResp{child: cache_id, addr: addr, state: state, data: line});
          stateArray[index] <= state;
        end //we're already either downgraded or invalid with a different tag
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
		if (isValid(ldBuffSearch)) begin // hit!
			let bufferIndex = tpl_1(validValue(ldBuffSearch));
			let ldBuffData = tpl_2(validValue(ldBuffSearch));
			ldBuff.remove(bufferIndex);
			returnData(ldBuffData.token, line[offset]);
      //Removed return to Ready state so it keeps taking requests off the ldBf
		end else begin
			status <= StHitState;
		end
	endrule

	rule processStHitState(status == StHitState);
		let resp = memRespHolder;
		let addr = resp.addr;
		let index = getIndex(addr);
		let tag = getTag(addr);
		let line = dataArray[index];
		let state = resp.state;
    //TODO: doesn't check for M state!
    if (!stQ.empty) begin
      StQData stQHead = stQ.first;
      Bool stQHit = (stateArray[index] == M && getTag(stQHead.addr) == tag && getIndex(stQHead.addr) == index);
      if (stQHit) begin  //hit at head of store queue!
        stQ.deq;
        line[getOffset(stQHead.addr)] = stQHead.data;
        dataArray[index] <= line;
      //Removed return to Ready state so it keeps taking requests off the stQ
		  end else begin
			  status <= StReqState;
      end
		end else status <= LdReqState;
	endrule

	rule processStReqState(status == StReqState);
    //Changed from memRespHolder to StQHead
		StQData stQHead = stQ.first;
		Addr reqAddr = stQHead.addr;
		if (can_send_upgrade_req(reqAddr, M) ) begin
			send_upgrade_req(reqAddr, M);
		end
		status <= LdReqState;
	endrule

	rule processLdReqState(status == LdReqState);
		let ldBuffConflict = ldBuff.searchConflict(memRespHolder.addr);
		if (isValid(ldBuffConflict)) begin
			Addr reqAddr = validValue(ldBuffConflict).addr;
			MSI reqState = S; //Not sure about this
			if (can_send_upgrade_req(reqAddr, reqState) ) begin
				send_upgrade_req(reqAddr, reqState);
			end
		end
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
		if (op == Ld) begin
			Maybe#(Data) fromStQ = stQ.search(addr);
			if (isValid(fromStQ)) begin
				let d = validValue(fromStQ);
				returnData(token, d);
			end else begin // Check cache
				Bool cacheHit = (stateArray[index] > I && tagArray[index] == tag);
				if (cacheHit) begin
					let d = dataArray[index][offset];
					returnData(token, d);
				end else begin // Insert into load buffer, send upgrade request if necessary & possible
					ldBuff.enq(LdBuffData{addr: addr, op: op, token: token});
					if (can_send_upgrade_req(addr, S) ) begin
						send_upgrade_req(addr, S);
					end
				end
			end
		end else begin //Store
			if (stQ.empty && stateArray[index] == M && tagArray[index] == tag) begin //Store hit
				let line = dataArray[index];
				line[offset] = data;
				dataArray[index] <= line;
			end else begin //Store miss
				stQ.enq(StQData{addr: addr, data: data, op: op, token: token});

				if (can_send_upgrade_req(addr, M) ) begin
					send_upgrade_req(addr, M);
				end
			end
		end

	endmethod

  method ActionValue#(NBCacheResp) resp;
		hitQ.deq;
	  return hitQ.first;
	endmethod
endmodule

//Questions
//Does waitc need to include information about what state it's sending a request for?
//Can we always send a request if the tag is the same and the cacheline state is less than the upgrade request?
//Does the cacheline state need to be strictly lower than the upgrade request in order for it to be able to fire, or can it be the same?
//In other words: Is there any situation where you would want to upgrade to the same state?
