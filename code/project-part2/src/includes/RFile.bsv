// Physical register file

// Contains three implementations:
// mkRFile: Standard RFile with read < write
// mkCFRfile: Conflict-free RFile with read CF write
// mkBypassRFile: Bypass RFile with write < read

import ProcTypes::*;
import Vector::*;
import Ehr::*;

interface RFile;
    method Action wr( PhyRegIndex r, Data data );
    method Data rd1( PhyRegIndex r );
    method Data rd2( PhyRegIndex r );
    method Data rd3( PhyRegIndex r );
    method Data rd4( PhyRegIndex r );
endinterface

module mkRFile( RFile );
    Vector#(NumPhyReg, Reg#(Data)) rfile <- replicateM(mkReg(0));

    method Action wr( PhyRegIndex r, Data data );
        if(r !=0) begin
            rfile[r] <= data;
        end
    endmethod

    method Data rd1( PhyRegIndex r ) = rfile[r];
    method Data rd2( PhyRegIndex r ) = rfile[r];
    method Data rd3( PhyRegIndex r ) = rfile[r];
    method Data rd4( PhyRegIndex r ) = rfile[r];
endmodule

module mkCFRFile( RFile );
    Vector#(NumPhyReg, Reg#(Data)) rfile <- replicateM(mkReg(0));

    Ehr#(2, Maybe#(Tuple2#(PhyRegIndex,Data))) write_req <- mkEhr(tagged Invalid);

    rule handle_write_req( isValid(write_req[1]) );
        let x = fromMaybe(?, write_req[1]);
        let r = tpl_1(x);
        let data = tpl_2(x);
        rfile[r] <= data;
        write_req[1] <= tagged Invalid;
    endrule

    method Action wr( PhyRegIndex r, Data data );
        if(r != 0) begin
            write_req[0] <= tagged Valid tuple2( r, data );
        end
    endmethod

    method Data rd1( PhyRegIndex r ) = rfile[r];
    method Data rd2( PhyRegIndex r ) = rfile[r];
    method Data rd3( PhyRegIndex r ) = rfile[r];
    method Data rd4( PhyRegIndex r ) = rfile[r];
endmodule

(* synthesize *)
module mkBypassRFile( RFile );
    Vector#(NumPhyReg, Ehr#(2,Data)) rfile <- replicateM(mkEhr(0));

    method Action wr( PhyRegIndex r, Data data );
        if(r != 0) begin
            rfile[r][0] <= data;
        end
    endmethod

    method Data rd1( PhyRegIndex r ) = rfile[r][1];
    method Data rd2( PhyRegIndex r ) = rfile[r][1];
    method Data rd3( PhyRegIndex r ) = rfile[r][1];
    method Data rd4( PhyRegIndex r ) = rfile[r][1];
endmodule
