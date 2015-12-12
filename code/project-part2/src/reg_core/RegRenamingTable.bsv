// This module is shared between decode, commit, and mispredict rules
import Vector::*;

import ProcTypes::*;
import RegCheckpointManager::*;
import RegFreeList::*;

interface RenamingTable;
	method PhyRegIndex lookup1(ArchRegIndex a);
	method PhyRegIndex lookup2(ArchRegIndex a);
	method PhyRegIndex lookup3(ArchRegIndex a);
	method Action updateTable(ArchRegIndex a, PhyRegIndex p);
	method ActionValue#(PhyRegIndex) rename(ArchRegIndex a);
	method Action free1(PhyRegIndex p);
	method ActionValue#(CheckpointTag) makeCheckpoint();
	method Action restoreCheckpoint(CheckpointTag tag, Bit#(NumCheckpoint) brBits);
	method Action freeCheckpoint(CheckpointTag tag); //Only for commit branch instruction.
    method Bit#(NumCheckpoint) curBranchBits();
endinterface

(* synthesize *)
module mkRegRenamingTable(RenamingTable);
    // Active renaming table and free list
	Vector#(NumArchReg, Reg#(PhyRegIndex)) currentTable;
    for( Integer i = 0 ; i < valueOf(NumArchReg) ; i = i+1 ) begin
        currentTable[i] <- mkReg(fromInteger(i));
    end
    FreeList#(FreeListSize) freeList <- mkRegFreeList();

    // Checkpoints for branches
	Vector#(NumCheckpoint, Vector#(NumArchReg,Reg#(PhyRegIndex))) tableCheckpoint <- replicateM(replicateM(mkReg(0)));
	Vector#(NumCheckpoint, Reg#(Bit#(TLog#(FreeListSize)))) freeListCheckpoint <- replicateM(mkReg(0));

    // Bookkeeping module for free checkpoints
    CheckpointManager checkpointManager <- mkRegCheckpointManager();


	Vector#(NumArchReg, Reg#(PhyRegIndex)) decode_currentTable;
	Vector#(NumArchReg, Reg#(PhyRegIndex)) commit_currentTable;
	Vector#(NumArchReg, Reg#(PhyRegIndex)) mispredict_currentTable;


	method PhyRegIndex lookup1(ArchRegIndex archReg);
        if( archReg == 0 ) begin
            return 0;
        end else begin
            return currentTable[archReg];
        end
	endmethod
	
	method PhyRegIndex lookup2(ArchRegIndex archReg);
        if( archReg == 0 ) begin
            return 0;
        end else begin
            return currentTable[archReg];
        end
	endmethod
	
	method PhyRegIndex lookup3(ArchRegIndex archReg);
        if( archReg == 0 ) begin
            return 0;
        end else begin
            return currentTable[archReg];
        end
	endmethod
	
	//The problem is to rollback really quickly -> in the minimal number of cycles
	// -> Is the next method sufficient?
	method Action updateTable(ArchRegIndex archReg, PhyRegIndex phy);
        if( archReg != 0 ) begin
            currentTable[archReg] <= phy;
            // Update free list as necessary
            freeList.undeqOne();
        end
	endmethod

	//Maximum one by cycle
	method ActionValue#(PhyRegIndex) rename(ArchRegIndex archReg) ;
        if( archReg == 0 ) begin
            return 0;
        end else begin
            let freePhy = freeList.first();
            freeList.deq;
            currentTable[archReg] <= freePhy;
            return freePhy;
        end
	endmethod

	//Can it be several by cycle? Let's assume that not.	
	method Action free1(PhyRegIndex phy);
        if( phy != 0 ) begin
            freeList.enq(phy);
        end
	endmethod

	//Return the tag of the snapshot which is taken.
	method ActionValue#(CheckpointTag) makeCheckpoint();
		let tag <- checkpointManager.newCheckpoint();
		for(Integer i=0; i < valueOf(NumArchReg); i = i + 1 )begin
			tableCheckpoint[tag][i] <= currentTable[i];
		end
	        freeListCheckpoint[tag] <= freeList.getHeadIndex;
		return tag;
	endmethod

    //We should probably also free the tag here.
    method Action restoreCheckpoint(CheckpointTag tag, Bit#(NumCheckpoint) brBits);
        // keep tag as active checkpoint
        checkpointManager.rollbackCheckpoint( brBits | (1 << tag) );
        for(Integer i=0; i < valueOf(NumArchReg); i = i + 1 ) begin
            currentTable[i] <= tableCheckpoint[tag][i];
        end
        freeList.undeq( freeListCheckpoint[tag] );
    endmethod

	//Do we need to think more about this next guy?
	method Action freeCheckpoint(CheckpointTag tag);
        checkpointManager.freeCheckpoint(tag);
	endmethod

    method Bit#(NumCheckpoint) curBranchBits();
        return checkpointManager.activeCheckpoints;
    endmethod
endmodule
