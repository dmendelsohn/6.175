import ProcTypes::*;
import Ehr::*;
import Vector::*;

interface BrBitsReg;
    interface Vector#(NumCheckpoint, Reg#(Bit#(1))) b; // short for bit, but that word is reserved
    interface Reg#(Bit#(NumCheckpoint))             all;
endinterface

module mkBrBitsReg(BrBitsReg);
    Vector#(NumCheckpoint, Reg#(Bit#(1))) _b <- replicateM(mkReg(0));

    return (interface BrBitsReg;
                interface Vector b = _b;
                interface Reg all;
                    method Action _write( Bit#(NumCheckpoint) x );
                        for( Integer i = 0 ; i < valueOf(NumCheckpoint) ; i = i+1 ) begin
                            _b[i] <= x[i];
                        end
                    endmethod
                    method Bit#(NumCheckpoint) _read;
                        Bit#(NumCheckpoint) ret = 0;
                        for( Integer i = 0 ; i < valueOf(NumCheckpoint) ; i = i+1 ) begin
                            ret[i] = _b[i];
                        end
                        return ret;
                    endmethod
                endinterface
            endinterface);
endmodule

interface BrBitsEhr#(numeric type n);
    interface Vector#(NumCheckpoint, Ehr#(n, Bit#(1)))  b; // short for bit, but that word is reserved
    interface Ehr#(n, Bit#(NumCheckpoint))              all;
endinterface

module mkBrBitsEhr(BrBitsEhr#(n));
    Vector#(NumCheckpoint, Ehr#(n, Bit#(1))) _b <- replicateM(mkEhr(0));
    Ehr#(n, Bit#(NumCheckpoint)) _all;
    for( Integer ehr_port = 0 ; ehr_port < valueOf(n) ; ehr_port = ehr_port + 1 ) begin
        _all[ehr_port] = (interface Reg;
                            method Action _write( Bit#(NumCheckpoint) x );
                                for( Integer i = 0 ; i < valueOf(NumCheckpoint) ; i = i+1 ) begin
                                    _b[i][ehr_port] <= x[i];
                                end
                            endmethod
                            method Bit#(NumCheckpoint) _read;
                                Bit#(NumCheckpoint) ret = 0;
                                for( Integer i = 0 ; i < valueOf(NumCheckpoint) ; i = i+1 ) begin
                                    ret[i] = _b[i][ehr_port];
                                end
                                return ret;
                            endmethod
                        endinterface);
    end
    interface Vector b = _b;
    interface Ehr all = _all;
endmodule
