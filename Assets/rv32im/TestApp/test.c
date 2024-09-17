#include <stdint.h>

// All hardware-accelerated structures must be 128-bit aligned.
#define ALIGN __attribute__((aligned(128)))

uint32_t termdata[25][80] ALIGN;
uint32_t backscreendata[16][32] ALIGN;

#include "vrcrv.h"

struct Hardware hardwaredef ALIGN = 
{
	.termsizeX = 80,
	.termsizeY = 25,
	.termscrollY = 0,
	.termscrollX = 0,
	.termdata = &termdata[0][0],

	.backscreenX = 32,
	.backscreenY = 16,
	.backscreenSY = 0,
	.backscreenSX = 0,
	.backscreendata = &backscreendata[0][0],
};

#include "microlibc.c"

void main( void )
{
	termdata[0][0] = 'X';	
	//_write( 0, "hello\nworld\n", 12 );
	printf( "Hello, world!\nTesting\n" );
	int i;

	backscreendata[0][0] = 'B';

	for( i = 0; ; i++ )
	{
		cursorx = 0;
		cursory = 2;
		printf( "%d\n", i );
		printf( "%d %d %d %d    \n", EXTCAM[0], EXTCAM[4], EXTCAM[8], EXTCAM[12] );
		printf( "%d %d %d %d    \n", EXTCAM[1], EXTCAM[5], EXTCAM[9], EXTCAM[13] );
		printf( "%d %d %d %d    \n", EXTCAM[2], EXTCAM[6], EXTCAM[10], EXTCAM[14] );
		printf( "%d %d %d %d    \n", EXTCAM[3], EXTCAM[7], EXTCAM[11], EXTCAM[15] );
		printf( "%d %d\n", EXTCAM[16]/1024, EXTCAM[17] );
		pcont();
	}	
//	while(1);
}


void otherharts( int hartid )
{
	int k = hartid;
	while(1)
	{
		k++;
		backscreendata[hartid/8][(hartid%8)*4+0] = '0' + ((k/1000)%10);
		backscreendata[hartid/8][(hartid%8)*4+1] = '0' + ((k/100)%10);
		backscreendata[hartid/8][(hartid%8)*4+2] = '0' + ((k/10)%10);
		backscreendata[hartid/8][(hartid%8)*4+3] = '0' + (k%10);
		pcont();
	}
}