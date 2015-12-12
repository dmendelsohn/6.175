volatile int core0_tries = 0;
volatile int core0_success = 0;
volatile int core1_tries = 0;
volatile int core1_success = 0;
volatile int shared_count = 0;

#define MAX_COUNT 1000

int count0()
{
    int *mem_ptr = (int*) 4;

    while( core0_success < MAX_COUNT )
    {
        int ret = atomicIncrement(&shared_count);
        core0_tries++;
        if( ret == 1 ) {
            core0_success++;
        }
        // now do some random work as a delay
        mem_ptr = (int*) (*mem_ptr + (int) mem_ptr + 4);
    }

    // Wait for main1 to finish
    while( core1_success < MAX_COUNT );

    printStr("core0 had "); printInt( core0_success ); printStr(" successes out of "); printInt( core0_tries ); printStr(" tries\n");
    printStr("core1 had "); printInt( core1_success ); printStr(" successes out of "); printInt( core1_tries ); printStr(" tries\n");
    printStr("shared_count = "); printInt( shared_count ); printStr("\n");
    return ((core0_success + core1_success) - shared_count);
}

int count1()
{
    int *mem_ptr = (int*) 8;
    while( core1_success < MAX_COUNT )
    {
        int ret = atomicIncrement(&shared_count);
        core1_tries++;
        if( ret == 1 ) {
            core1_success++;
        }
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
