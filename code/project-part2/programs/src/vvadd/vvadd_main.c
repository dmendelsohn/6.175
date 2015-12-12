//**************************************************************************
// Vector-vector add benchmark
//--------------------------------------------------------------------------
//
// This benchmark uses adds to vectors and writes the results to a
// third vector. The input data (and reference data) should be
// generated using the vvadd_gendata.pl perl script and dumped
// to a file named dataset1.h The smips-gcc toolchain does not
// support system calls so printf's can only be used on a host system,
// not on the smips processor simulator itself. You should not change
// anything except the HOST_DEBUG and PREALLOCATE macros for your timing
// runs.

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
// vvadd function

void vvadd( int n, int a[], int b[], int c[] )
{
  int i;
  for ( i = 0; i < n; i++ )
    c[i] = a[i] + b[i];
}

//--------------------------------------------------------------------------
// Main

int main( int argc, char* argv[] )
{
  int results_data[DATA_SIZE];

  // Do the vvadd

  int cycles, insts;
  cycles = getTime();
  insts = getInsts();
  vvadd(DATA_SIZE, input1_data, input2_data, results_data );
  cycles = getTime() - cycles;
  insts = getInsts() - insts;
  printStr("Cycles = "); printInt(cycles); printChar('\n');
  printStr("Insts  = "); printInt(insts); printChar('\n');

  // Check the results

  return !(verify( DATA_SIZE, results_data, verify_data ));

}
