import ProcTypes::*;
import Vector::*;

interface FreeList#(numeric type n);
    method Action deq();
    method PhyRegIndex first();
    method Bit#(TLog#(n)) getHeadIndex();
    method Action undeq(Bit#(TLog#(n)) tag);
    method Action enq(PhyRegIndex tag);
    method Action undeqOne();
endinterface

module mkRegFreeList( FreeList#(n) );
    // n is size of fifo

    // storage elements
    Vector#( n, Reg#(PhyRegIndex) ) data;
    for( Integer i = 0 ; i < valueOf(n) ; i = i+1 ) begin
        data[i] <- mkReg(fromInteger(i + valueOf(NumArchReg)));
    end
    Reg#(Bit#(TLog#(n))) enqP  <- mkReg(0);
    Reg#(Bit#(TLog#(n))) deqP  <- mkReg(0);
    Reg#(Bool)           empty <- mkReg(False);
    Reg#(Bool)           full  <- mkReg(True);

    // // sanity check
    // Vector#(TAdd#(NumArchReg,n), Reg#(Bool)) isFree;
    // for( Integer i = 0 ; i < valueOf(NumArchReg) ; i = i+1 ) begin
    //     isFree[i] <- mkReg(False);
    // end
    // for( Integer i = 0 ; i < valueOf(n) ; i = i+1 ) begin
    //     isFree[i + valueOf(NumArchReg)] <- mkReg(True);
    // en

    // useful value
    Bit#(TLog#(n))      max_index = fromInteger(valueOf(n)-1);
    
    Vector#( n, Reg#(PhyRegIndex) ) decode_data     = data;
    Reg#(Bit#(TLog#(n)))            decode_enqP     = enqP;
    Reg#(Bit#(TLog#(n)))            decode_deqP     = deqP;
    Reg#(Bool)                      decode_empty    = empty;
    Reg#(Bool)                      decode_full     = full;

    Vector#( n, Reg#(PhyRegIndex) ) commit_data     = data;
    Reg#(Bit#(TLog#(n)))            commit_enqP     = enqP;
    Reg#(Bit#(TLog#(n)))            commit_deqP     = deqP;
    Reg#(Bool)                      commit_empty    = empty;
    Reg#(Bool)                      commit_full     = full;

    Vector#( n, Reg#(PhyRegIndex) ) mispredict_data     = data;
    Reg#(Bit#(TLog#(n)))            mispredict_enqP     = enqP;
    Reg#(Bit#(TLog#(n)))            mispredict_deqP     = deqP;
    Reg#(Bool)                      mispredict_empty    = empty;
    Reg#(Bool)                      mispredict_full     = full;

    // // sanity check
    // Vector#(TAdd#(NumArchReg,n), Reg#(Bool)) decode_isFree = isFree;
    // Vector#(TAdd#(NumArchReg,n), Reg#(Bool)) commit_isFree = isFree;
    // Vector#(TAdd#(NumArchReg,n), Reg#(Bool)) mispredict_isFree = isFree;

    // decode methods
    method Action deq if( !decode_empty );
        // Increment dequeue pointer
        let next_deqP = (decode_deqP == max_index) ? 0 : decode_deqP + 1;
        if( next_deqP == decode_enqP ) begin
            decode_empty <= True;
        end
        decode_full <= False;
        decode_deqP <= next_deqP;

        // // sanity check
        // if( !decode_isFree[decode_data[decode_deqP]] ) begin
        //     $fwrite(stderr, "ERROR: mkRegFreeList sanity check failed\n");
        //     $fwrite(stderr, "An already-freed register exited the free list again\n");
        //     $finish;
        // end
        // decode_isFree[decode_data[decode_deqP]] <= False;
    endmethod

    method PhyRegIndex first if( !decode_empty );
        return decode_data[decode_deqP];
    endmethod

    method Bit#(TLog#(n)) getHeadIndex();
        return decode_deqP;
    endmethod

    // commit methods
    // the guard is not needed by construction
    method Action enq(PhyRegIndex x);
        // sanity check
        if( commit_full ) begin
            $fwrite(stderr, "ERROR: enqueuing into a full FreeList");
            $finish;
        end

        commit_data[commit_enqP] <= x;
        let next_enqP = (commit_enqP == max_index) ? 0 : commit_enqP + 1;
        commit_enqP <= next_enqP;
        if( next_enqP == commit_deqP ) begin
            commit_full <= True;
        end
        commit_empty <= False;

        // // sanity check
        // if( commit_isFree[x] ) begin
        //     $fwrite(stderr, "ERROR: mkRegFreeList sanity check failed\n");
        //     $fwrite(stderr, "An free register was freed again\n");
        // end
        // commit_isFree[x] <= True;
    endmethod

    // mispredict methods
    method Action undeq(Bit#(TLog#(n)) tag);
        // TODO: Implement
        mispredict_deqP <= tag;
        if( tag == mispredict_deqP ) begin
            // no change?
            if( tag == mispredict_enqP ) begin
                // not sure what to do
                $fwrite(stderr, "WARNING: free list is undequeuing to with tag == deqP == enqP\n");
            end
        end else if( tag == mispredict_enqP ) begin
            mispredict_full <= True;
            mispredict_empty <= False;
        end else begin
            mispredict_empty <= False;
        end

        // // sanity check
        // $fwrite(stderr, "WARNING: Sanity checks broken\n");
    endmethod    

    method Action undeqOne if( !mispredict_full );
        let next_deqP = (mispredict_deqP == 0) ? max_index : mispredict_deqP - 1;
        if( next_deqP == mispredict_enqP ) begin
            mispredict_full <= True;
        end
        mispredict_deqP <= next_deqP;
        mispredict_empty <= False;

        // // sanity check
        // if( mispredict_isFree[mispredict_data[mispredict_deqP-1]] ) begin
        //     $fwrite(stderr, "ERROR: mkRegFreeList sanity check failed\n");
        //     $fwrite(stderr, "An free register was freed again (through undeqOne)\n");
        // end
        // mispredict_isFree[mispredict_data[mispredict_deqP-1]] <= True;
    endmethod    
endmodule
