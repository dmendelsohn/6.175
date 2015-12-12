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

// Input/Reference Data

#include "dataset1.h"

// Helper functions

int verify( int n, int test[], int correct[] )
{
  int i;
  for ( i = 0; i < n; i++ ) {
    if ( test[i] != correct[i] ) {
      return 2;
    }
  }
  return 1;
}

//--------------------------------------------------------------------------
// Main

int main( int argc, char* argv[] )
{
  int results_data[DATA_SIZE];

  // Do the filter
  int cycles, insts;
  cycles = getTime();
  insts = getInsts();
  median( DATA_SIZE, input_data, results_data );
  cycles = getTime() - cycles;
  insts = getInsts() - insts;
  printStr("Cycles = "); printInt(cycles); printChar('\n');
  printStr("Insts  = "); printInt(insts); printChar('\n');

  // Check the results
  return !(verify( DATA_SIZE, results_data, verify_data ));

}
