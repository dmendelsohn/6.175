int main(int core) {
    if( core == 0 ) {
        printStr( "I'm core 0!\n" );
    } else {
        printStr( "I'm not core 0!\n" );
    }
    return 0;
}
