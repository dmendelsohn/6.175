# define BLOCK_SIZE sizeof ( struct s_block )

# define align4(x) (((((x)-1)>>2)<<2)+4)

typedef struct s_block *t_block ;

struct s_block {
	unsigned int size;
	t_block	next;
	int	free;
	char data[1];
};

void *base = 0;

void *ptrMemory = 0;


t_block find_block ( t_block *last , unsigned int size ){
	t_block b=base;
	while (b && !((b->free==1) &&( b->size >= size) )) {
		*last = b;
		b = b->next;
	}
	return (b);
};


t_block extend_heap ( t_block last , unsigned int s){
	t_block b;
	b = ptrMemory;
	ptrMemory = ptrMemory + BLOCK_SIZE + s;
	b->size = s;
	b->next = 0;
	if (last)
		last ->next = b;
	b->free = 0;
	return (b);
};


void* malloc( unsigned int size ){
	t_block b,last;
	unsigned int s;
	s = align4(size );
if (base){
	last = base;
	b = find_block (&last ,s);
	if (b) {
		b->free = 0;
	} else {
		b = extend_heap(last ,s);
	}}
else {
	base = 0x01000000; //Address of the heap
	b=base;
	ptrMemory = base+ BLOCK_SIZE + s;
	b->size = s;
	b->next = 0;
	b->free = 0;
}


return (b->data );
};

void free(int* addr){
	*(addr-1) = 1;
};

int main()
{

	return 0;
};
