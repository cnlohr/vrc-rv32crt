
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
			termdata[cursory % hardwaredef.termsizeY][cursorx] = c;
			cursorx++;
		}
		
		if( cursorx == hardwaredef.termsizeX )
		{
			cursorx = 0;
			cursory++;
		}
		if( cursory == ( hardwaredef.termsizeY + hardwaredef.termscrollY ) )
		{
			int looprow = ( hardwaredef.termsizeY + hardwaredef.termscrollY ) % hardwaredef.termsizeY;
			hardwaredef.termscrollY++;
			memset( termdata[looprow], 0, hardwaredef.termsizeX*4 );
		}
	}
}

