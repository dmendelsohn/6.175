import ProcTypes::*;

interface CheckpointManager;
	method ActionValue#(Bit#(TLog#(NumCheckpoint))) newCheckpoint();
	method Action freeCheckpoint( Bit#(TLog#(NumCheckpoint)) checkpoint );
    method Action rollbackCheckpoint( Bit#(NumCheckpoint) oldCheckpoints );
	method Bit#(NumCheckpoint) activeCheckpoints();
endinterface

module mkRegCheckpointManager(CheckpointManager);
    Reg#(Bit#(NumCheckpoint)) active <- mkReg(0);

    Reg#(Bit#(NumCheckpoint)) decode_active = active;
    Reg#(Bit#(NumCheckpoint)) commit_active = active;
    Reg#(Bit#(NumCheckpoint)) mispredict_active = active;

    // compute available checkpoint
    Maybe#(Bit#(TLog#(NumCheckpoint))) available_checkpoint = tagged Invalid;
    for( Integer i = valueOf(NumCheckpoint)-1 ; i >= 0 ; i = i-1 ) begin
        if( decode_active[i] == 0 ) begin
            available_checkpoint = tagged Valid fromInteger(i);
        end
    end

    // decode methods
	method ActionValue#(Bit#(TLog#(NumCheckpoint))) newCheckpoint() if( isValid(available_checkpoint) );
        return fromMaybe(?, available_checkpoint);
    endmethod

	method Bit#(NumCheckpoint) activeCheckpoints();
        return decode_active;
    endmethod

    // commit method
	method Action freeCheckpoint( Bit#(TLog#(NumCheckpoint)) checkpoint );
        commit_active[checkpoint] <= 0;
    endmethod

    // mispredict method
    method Action rollbackCheckpoint( Bit#(NumCheckpoint) oldCheckpoints );
        mispredict_active <= oldCheckpoints;
    endmethod
endmodule
