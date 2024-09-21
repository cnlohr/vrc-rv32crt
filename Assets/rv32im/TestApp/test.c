#include <stdint.h>

#include "vrcrv.h"

uint32_t termdata[25][80] ALIGN;
uint32_t backscreendata[16][32] ALIGN;

#include "pistol.h"

struct Hardware hardwaredef ALIGN = 
{
	.nTermSizeX = 80,
	.nTermSizeY = 25,
	.nTermScrollX = 0,
	.nTermScrollY = 0,
	.pTermData = &termdata[0][0],

	.nBackscreenX = 32,
	.nBackscreenY = 16,
	.nBackscreenSX = 0,
	.nBackscreenSY = 0,
	.pBackscreenData = &backscreendata[0][0],
};

#include "microlibc.c"


struct holoSteamObject hso ALIGN;
struct holoTransform pistolBase ALIGN;

void main( void )
{
	termdata[0][0] = 'X';	
	//_write( 0, "hello\nworld\n", 12 );
	printf( "Hello, world!\nTesting\n" );
	int i;

	backscreendata[0][0] = 'B';

	hardwaredef.holostreamObjects[0] = &hso;	
	hso.nNumberOfTriangles = pistol_Tris;
	hso.nMode = pistol_Mode;
	hso.pTriangleList = pistol_Data;
	hso.pXform1 = &pistolBase;

	for( i = 0; ; i++ )
	{
		cursorx = 0;
		cursory = 2;
		printf( "%d\n", i );
		//printf( "%d %d %d %d %d   \n", HID->PointerX, HID->PointerX2, HID->Screen[3][0], HID->GunBack[3][0], HID->GunTip[3][0] );
		//printf( "%d %d %d %d %d   \n", HID->PointerY, HID->PointerY2, HID->Screen[3][1], HID->GunBack[3][1], HID->GunTip[3][1] );
		//printf( "%d %d %d %d %d   \n", HID->PointerZ, HID->PointerZ2, HID->Screen[3][2], HID->GunBack[3][2], HID->GunTip[3][2] );
		//printf( "%d %d %d %d %d   \n", 0, 0, HID->Screen[3][3], HID->GunBack[3][3], HID->GunTip[3][3] );
		printf( "%d %d    \n", HID->PointerX, HID->PointerX2 );
		printf( "%d %d    \n", HID->PointerY, HID->PointerY2 );
		printf( "%d %d    \n", HID->PointerZ, HID->PointerZ2 );
		printf( "%d   %d       \n", HID->TimeMS, HID->TriggerRight );
		//printf( "%d %d\n", EXTCAM[16]/1024, EXTCAM[17] );
		
		
		backscreendata[HID->PointerY * 16 / 4096 ][HID->PointerX * 32/4096 ] = 'X';
		backscreendata[HID->PointerY2 * 16 / 4096][HID->PointerX2 * 32/4096] = 'O';
//	HIDMatrix Screen;
//	HIDMatrix GunStock;
//	HIDMatrix GunTip;

		pcont();
	}	
//	while(1);
}


void otherharts( int hartid )
{
	int k = hartid;
	while(1)
	{
		
		pistolBase.S = 4096;
		pistolBase.tX = 4096;
		pistolBase.qW = 4096;
		if( pistolBase.tX > 8192 ) pistolBase.tX = 0;

		k++;
		backscreendata[hartid/8][(hartid%8)*4+0] = '0' + ((k/1000)%10);
		backscreendata[hartid/8][(hartid%8)*4+1] = '0' + ((k/100)%10);
		backscreendata[hartid/8][(hartid%8)*4+2] = '0' + ((k/10)%10);
		backscreendata[hartid/8][(hartid%8)*4+3] = '0' + (k%10);
		pcont();
	}
}