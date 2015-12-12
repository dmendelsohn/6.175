/*

Copyright (C) 2012 Muralidaran Vijayaraghavan <vmurali@csail.mit.edu>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

*/



void printInt(int c) {
  asm ("mtc0 %0, $18" : : "r" (c));
}

void printChar(int x) {
  int c = (int) x;
  asm ("mtc0 %0, $19" : : "r" (c));
}

void printStr(char* x) {
  while(1) {
     int* y = (int*) x;
     unsigned int fullC = *y;
     unsigned int mod = ((unsigned int)x) & 0x3;
     unsigned int shift = 24 - (mod << 3);
     unsigned int c = (fullC & (0xff << shift)) >> shift;
     if(c == (unsigned int)'\0')
       break;
     printChar((int)c);
     x++;
  }
}
