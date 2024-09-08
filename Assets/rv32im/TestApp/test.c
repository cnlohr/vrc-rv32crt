#include <stdint.h>

// All hardware-accelerated structures must be 128-bit aligned.
#define ALIGN __attribute__((aligned(128)))

uint32_t termdata[25][80] ALIGN;

struct Hardware
{
	uint32_t termsizeX;
	uint32_t termsizeY;
	uint32_t termscrollY;
	uint32_t * termdata;
} hardwaredef ALIGN = 
{
	.termsizeX = 80,
	.termsizeY = 25,
	.termscrollY = 0,
	.termdata = &termdata[0][0],
};

#include "microlibc.c"

int main()
{
	termdata[0][0] = 'a';	
	//_write( 0, "hello\nworld\n", 12 );
	printf( "Hello, world!\nTesting\n" );
	int i;
	for( i = 0; ; i++ )
	{
		printf( "%d ", i );
	}
//	while(1);
}

