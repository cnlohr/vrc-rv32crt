#include <stdint.h>

#include "vrcrv.h"

int booted ALIGN;

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

void main( void )
{
	termdata[0][0] = 'X';	
	//_write( 0, "hello\nworld\n", 12 );
	printf( "Hello, world!\nTesting\n" );
	int i;

	backscreendata[0][0] = 'B';

	booted = 1;

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


void eulertoquat( int x, int y, int z, int32_t * quat )
{
	// ? what do ?
	
}


struct holoSteamObject hso[256] ALIGN;
struct holoTransform pistolBase0[256] ALIGN;
struct holoTransform pistolBase1[256] ALIGN;

void otherharts( int hartid )
{
	int k = hartid;
	int i;
	
	while( !booted );
	
	for( i = 0; i < hartid*2; i++ )
		pcont();

	for( i = 0; i < 4; i++ )
	{
		struct holoSteamObject * ho = &hso[hartid*4+i];
		hardwaredef.holostreamObjects[hartid * 4+i] = ho;	
		ho->nNumberOfTriangles = pistol_Tris;
		ho->pTriangleList = pistol_Data;
		ho->nMode = pistol_Mode;
		
		ho->nTransMode0 = 2;
		ho->nTransMode1 = 2;
		
		ho->pXform0 = &pistolBase0[hartid * 4 + i];
		ho->pXform1 = &pistolBase1[hartid * 4 + i];

		pistolBase0[hartid * 4 + i].tq.S = 4096*5;
		pistolBase1[hartid * 4 + i].tq.S = 4096;
		pistolBase0[hartid * 4 + i].tq.qW = 4096;
		pistolBase0[hartid * 4 + i].tq.tX = 4096 * 2;

		pistolBase1[hartid * 4 + i].tq.tY = 2048;
	}
	int torque = 4;
	while(1)
	{
		//pistolBase.tq.qW = 4096-i;
		//if( hartid == 1 )
		if( HID->PointerZ > 100 ) torque = HID->PointerX>>2;
	
		for( i = 0; i < 4; i++ )
		{
			struct holoSteamObject * ho = &hso[hartid*4+i];
			ho->pXform1->te.rX = k+i*16 + hartid * 64;
			ho->pXform1->te.rY = k+i*16 + hartid * 64 + 1024*3;
			ho->pXform1->te.rZ = k+i*16 + hartid * 64;

			ho->pXform0->te.rX = k+i*torque + hartid * torque*4;
			ho->pXform0->te.rY = k+i*torque + hartid * torque*4;
			ho->pXform0->te.rZ = k+i*torque + hartid * torque*4;
		}
		if( k > 4096 ) k = 0;

		k++;
		backscreendata[hartid/8][(hartid%8)*4+0] = '0' + ((k/1000)%10);
		backscreendata[hartid/8][(hartid%8)*4+1] = '0' + ((k/100)%10);
		backscreendata[hartid/8][(hartid%8)*4+2] = '0' + ((k/10)%10);
		backscreendata[hartid/8][(hartid%8)*4+3] = '0' + (k%10);
		pcont();
	}
}