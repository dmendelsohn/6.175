#define FIFO_SIZE 20
volatile int fifo_data[FIFO_SIZE] =
{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};
volatile int head_index_buffer[33] =
{
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0
};
volatile int tail_index_buffer[33] =
{
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0
};
// to prevent false sharing
volatile int* head_index = &head_index_buffer[16];
volatile int* tail_index = &tail_index_buffer[16];

char *message = "Hello World!\nThis message has been written to a software FIFO by core 0 and read and printed by core 1.";

// Core 0
// Generate the text
int core0()
{
    // copy "Hello World!" to a common fifo
    unsigned int data = 0;
    int new_tail_index = 0;
    int delay_index = 0;
    do {
        int* y = (int*) message;
        unsigned int fullC = *y;
        unsigned int mod = ((unsigned int)message) & 0x3;
        unsigned int shift = 24 - (mod << 3);
        data = (fullC & (0xff << shift)) >> shift;
        message++;

        for(delay_index = 0 ; delay_index < 10 ; delay_index++) {
        }
        
        // now write data to the fifo
        fifo_data[*tail_index] = (int) data;

        new_tail_index = *tail_index + 1;
        if( new_tail_index == FIFO_SIZE ) {
            new_tail_index = 0;
        }
        while( *head_index == new_tail_index ); // wait for consumer to catch up
        *tail_index = new_tail_index;
    } while( data != 0 );
    return 0;
}

// Core 1
// Print the text
int core1()
{
    // print the string found in the common fifo
    int data = 0;
    int new_head_index = 0;
    do {
        while( *head_index == *tail_index ); // wait for data to be produced
        data = fifo_data[*head_index];
        new_head_index = *head_index + 1;
        if( new_head_index == FIFO_SIZE ) {
            new_head_index = 0;
        }
        *head_index = new_head_index;
        if( data != 0 ) {
            printChar( data );
        }
    } while( data != 0 );
    return 0;
}

int main( int coreid ) {
    if( coreid == 0 ) {
        return core0();
    } else if( coreid == 1 ) {
        return core1();
    }
    return 0;
}
