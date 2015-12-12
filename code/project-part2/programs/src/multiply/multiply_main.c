// *************************************************************************
// multiply filter bencmark
// -------------------------------------------------------------------------
//
// This benchmark tests the software multiply implemenation. The
// input data (and reference data) should be generated using the
// multiply_gendata.pl perl script and dumped to a file named
// dataset1.h You should not change anything except the
// HOST_DEBUG and PREALLOCATE macros for your timing run.

#include "multiply.h"

//--------------------------------------------------------------------------
// Input/Reference Data

#include "dataset1.h"

//--------------------------------------------------------------------------
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
  int i;
  int results_data[DATA_SIZE];

  // Do the multiply
  int cycles, insts;
  cycles = getTime();
  insts = getInsts();
  for (i = 0; i < DATA_SIZE; i++) {
    results_data[i] = multiply( input_data1[i], input_data2[i] );
  }
  cycles = getTime() - cycles;
  insts = getInsts() - insts;
  printStr("Cycles = "); printInt(cycles); printChar('\n');
  printStr("Insts  = "); printInt(insts); printChar('\n');

  // Check the results

  return !(verify( DATA_SIZE, results_data, verify_data ));

}
