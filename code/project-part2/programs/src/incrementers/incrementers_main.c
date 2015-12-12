volatile int core0_count = 0;
volatile int core1_count = 0;
volatile int shared_count = 0;

int core0_tmp = 0;
int core1_tmp = 0;

#define MAX_COUNT 1000

int count0()
{
    int *mem_ptr = (int*) 4;
    while( core0_count < MAX_COUNT )
    {
        shared_count++;
        core0_count++;
        // now do some random work as a delay
        mem_ptr = (int*) (*mem_ptr + (int) mem_ptr + 4);
    }
    
    // Wait for main1 to finish
    while( core1_count < MAX_COUNT );

    printStr("core0_count = "); printInt( core0_count );
    printStr("\ncore1_count = "); printInt( core1_count );
    printStr("\nshared_count = "); printInt( shared_count );
    printStr("\n");
    return 0;
}

int count1()
{
    int *mem_ptr = (int*) 8;
    while( core1_count < MAX_COUNT )
    {
        shared_count++;
        core1_count++;
        // now do some random work as a delay
        mem_ptr = (int*) (*mem_ptr + (int) mem_ptr + 4);
    }

    return 0;
}

int main( int coreid )
{
    if( coreid == 0 ) {
        return count0();
    } else if( coreid == 1 ) {
        return count1();
    }
    return 0;
}
