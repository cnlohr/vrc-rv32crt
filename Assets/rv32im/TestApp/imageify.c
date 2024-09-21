#include <stdio.h>
#include <math.h>

#define STB_IMAGE_WRITE_IMPLEMENTATION

#include "stb_image_write.h"

#define W 2048

int main( int argc, char ** argv )
{
	if( argc != 3 )
	{
		fprintf( stderr, "Error: usage: [imageify] [in binary] [out image]\n" );
		return -1;
	}
	
	FILE * fin = fopen( argv[1], "rb" );
	if( !fin )
	{
		fprintf( stderr, "Error: can't open \"%s\"\n", argv[1] );
		return -2;
	}
	fseek( fin, 0, SEEK_END );
	int len = ftell( fin );
	fseek( fin, 0, SEEK_SET );
	int h = ((len + (W*4-1))/4/W);
	
	uint8_t * data = calloc( W * 4, h );
	int i;
	for( i = 0; i < h; i++ )
	{
		//fread( &data[W*(h-i-1)*4], 1, W*4, fin );
		fread( &data[W*i*4], 1, W*4, fin );
	}
	fclose( fin );

    int r = stbi_write_png( argv[2], W, h, 4, data, W*4 );

	if( r == 0 )
	{
		fprintf( stderr, "Error: can't write %s\n", argv[2] );
		return -3;
	}
	
	fprintf( stderr, "Successfully written %s (%d) (%dx%d)\n", argv[2], r, W, h );
	return 0;
}
