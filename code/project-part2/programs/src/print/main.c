void print() {
  int i;
  char *c = "hello world\n";
  char d[13];
  printChar('c');
  printStr(c);
  for(i = 0; i < 13; i++)
    d[i] = c[i];
  printChar('d');
  printStr(d);
  printInt(25);
}

int main() {
  int cycles, insts;
  cycles = getTime();
  insts = getInsts();
  print();
  cycles = getTime() - cycles;
  insts = getInsts() - insts;
  printStr("\nCycles = "); printInt(cycles); printChar('\n');
  printStr("Insts  = "); printInt(insts); printChar('\n');
  return 0;
}
