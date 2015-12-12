//**************************************************************************
// Median filter bencmark
//--------------------------------------------------------------------------
//
// This benchmark performs a 1D three element median filter. The
// input data (and reference data) should be generated using the
// median_gendata.pl perl script and dumped to a file named
// dataset1.h You should not change anything except the
// HOST_DEBUG and PREALLOCATE macros for your timing run.

#include "median.h"

//--------------------------------------------------------------------------
// Input/Reference Data

#include "dataset1.h"

//--------------------------------------------------------------------------
// Shared output data

volatile int results_data[DATA_SIZE];
volatile int main1_done = 0;
volatile int main1_insts = 0;
volatile int main1_cycles = 0;

//--------------------------------------------------------------------------
// Helper functions

int verify( int n, int test[], int correct[] )
{
  int i;
  for ( i = 0; i < n; i++ ) {
    if ( test[i] != correct[i] ) {
      return 1;
    }
  }
  return 0;
}

//--------------------------------------------------------------------------
// Main

int main0( )
{
  // start counting instructions and cycles
  int cycles, insts;
  cycles = getTime();
  insts = getInsts();

  // do the median filter
  median_first_half( DATA_SIZE, input_data, results_data );

  // stop counting instructions and cycles
  cycles = getTime() - cycles;
  insts = getInsts() - insts;

  // wait for main1 to finish
  while( main1_done == 0 );

  // print the cycles and inst count
  printStr("Cycles (core 0) = "); printInt(cycles); printChar('\n');
  printStr("Insts  (core 0) = "); printInt(insts); printChar('\n');
  printStr("Cycles (core 1) = "); printInt(main1_cycles); printChar('\n');
  printStr("Insts  (core 1) = "); printInt(main1_insts); printChar('\n');
  cycles = (cycles > main1_cycles) ? cycles : main1_cycles;
  insts = insts + main1_insts;
  printStr("Cycles  (total) = "); printInt(cycles); printChar('\n');
  printStr("Insts   (total) = "); printInt(insts); printChar('\n');

  // Check the results
  return verify( DATA_SIZE, results_data, verify_data );
}

int main1( )
{
  // start counting instructions and cycles
  int cycles, insts;
  cycles = getTime();
  insts = getInsts();

  // do the median filter
  median_second_half( DATA_SIZE, input_data, results_data );

  // stop counting instructions and cycles
  cycles = getTime() - cycles;
  insts = getInsts() - insts;
  main1_cycles = cycles;
  main1_insts = insts;
  main1_done = 1;

  // Return success
  return 0;
}

int main(int core) {
    if( core == 0 ) {
        return main0();
    } else {
        return main1();
    }
    return 0;
}
