
int cursorx;
int cursory;

int _write( int desc, const uint8_t * str, int len );

#include "microlibc.h"

int _write( int desc, const uint8_t * str, int len )
{
	int i;
	for( i = 0; i < len; i++ )
	{
		int c = str[i];
		if( c == '\n' )
		{
			cursorx = 0;
			cursory++;
		}
		else if( c == '\t' )
		{
			cursorx = (cursorx+4)&~4;
		}
		else
		{
			termdata[cursory % hardwaredef.nTermSizeY][cursorx] = c;
			cursorx++;
		}
		
		if( cursorx == hardwaredef.nTermSizeX )
		{
			cursorx = 0;
			cursory++;
		}
		if( cursory == ( hardwaredef.nTermSizeY + hardwaredef.nTermScrollY ) )
		{
			int looprow = ( hardwaredef.nTermSizeY + hardwaredef.nTermScrollY ) % hardwaredef.nTermSizeY;
			hardwaredef.nTermScrollY++;
			memset( termdata[looprow], 0, hardwaredef.nTermSizeX*4 );
		}
	}
}

