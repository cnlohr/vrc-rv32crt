#include <stdio.h>
#include <stdlib.h>

#define MAX_VERTICES 65536
#define MAX_TRIANGLES

double vertexData[MAX_VERTICES][6];
double vertexDataT[MAX_VERTICES][6];
double vertexDataN[MAX_VERTICES][6];
// TODO: Add normal/texture coordinate data.
int maxVertex;
int maxTexture;
int maxNormal;
double scale;

char thisLine[1024];
int thisPlace;
int lineno = 1;
int oTris = 0;

void WriteVertex1( FILE * fOut, int * ps )
{
	int pV = ps[0];
	if( pV == 0 || pV > maxVertex )
	{
		fprintf( stderr, "Out of range on line %d (%d)\n", lineno, pV );
		return;
	}
	double * vd = vertexData[pV-1];
	//printf( "%f %f %f  %f %f %f (%d)\n", vd[0], vd[1], vd[2], vd[3], vd[4], vd[5], pV );
	int colorr = vd[3] * 255.5;
	int colorg = vd[4] * 255.5;
	int colorb = vd[5] * 255.5;
	if( colorr < 0 ) colorr = 0; if( colorr > 255 ) colorr = 255;
	if( colorg < 0 ) colorg = 0; if( colorg > 255 ) colorg = 255;
	if( colorb < 0 ) colorb = 0; if( colorb > 255 ) colorb = 255;
	fprintf( fOut, "%7d,%7d,%7d, 0x%08x, ",
		(int)(vd[0]*scale), (int)(vd[1]*scale), (int)(vd[2]*scale),
		colorr | (colorg << 8) | (colorb << 16 ) | 0x1000000 );
}


int main( int argc, char ** argv )
{
	if( argc != 6 )
	{
		fprintf( stderr, "Error: Usage: objtoh [.obj file in] [.h file out] [name] [scale] [int mode]\n" );
		return -1;
	}
	FILE * fIn = fopen( argv[1], "rb" );
	if( !fIn || ferror( fIn ) )
	{
		fprintf( stderr, "Error: Could not open %s\n", argv[1] );
		return -2;
	}
	FILE * fOut = fopen( argv[2], "wb" );
	if( !fOut || ferror( fOut ) )
	{
		fprintf( stderr, "Error: Could not open %s\n", argv[2] );
		return -3;
	}
	
	int mode = atoi( argv[5] );
	scale = atof( argv[4] );
	if( scale < 0.0001 )
	{
		fprintf( stderr, "Error: Invalid scale\n" );
		return -4;
	}
	switch( mode )
	{
		case 1:
			fprintf( fOut, "#pragma once\n#include <stdint.h>\nint32_t %s_Data[] = {\n", argv[3] );
			break;
		default:
			fprintf( stderr, "Error: Mode options:\n 1: Vertex Colors\n" );
			return -6;
	}
	
	thisPlace = 0;
	int maxVP = 0;
	do
	{
		int c = getc( fIn );
		if( c == EOF || ferror( fIn ) ) break;
		
		if( c == '\n' )
		{
			if( thisPlace >= sizeof( thisLine ) - 2 )
			{
				fprintf( stderr, "Error: Line %d too long\n", lineno );
				continue;
			}
			thisLine[thisPlace++] = c;
			thisLine[thisPlace++] = 0;
			
			if( thisLine[0] == 'v' )
			{
				// Vertex
				const char * sread = 0;
				double * vd = 0;
				if( thisLine[1] == ' ' )
				{
					sread = thisLine + 2;
					vd = vertexData[maxVertex++];
				}
				else if( thisLine[1] == 't' )
				{
					sread = thisLine + 3;
					vd = vertexDataT[maxTexture++];
				}
				else if( thisLine[1] == 'n' )
				{
					sread = thisLine + 3;
					vd = vertexDataT[maxNormal++];
				}
				if( vd )
				{
					vd[0] = vd[1] = vd[2] = vd[3] = vd[4] = vd[5] = 1.0 / 0.0;
					int field = 0;
					int fstart = 0;
					int m;
					for( m = 0; sread[m] && field < 6; m++ )
					{
						if( sread[m] == '\n' || sread[m] == ' ' )
						{
							double v = atof( &sread[fstart] );
							vd[field++] = v;
							fstart = m;
						}
					}
					//printf( "%d %f %f %f %f %f %f [%s]\n", field, vd[0], vd[1], vd[2], vd[3], vd[4], vd[5], sread );
					if( field < 3 )
					{
						fprintf( stderr, "Error on line %d\n", lineno );
					}
					if( field > maxVP )
						maxVP = field;
				}
			}
			else if( thisLine[0] == 'f' )
			{
				int noF = 0;
				const char * sread = &thisLine[2];
				int c = 0;
				int k = 0;
				int s = 0;
				
				int face = 0;
				int pB = 0;
				int maxE = 0;
				int params[1024][10] = { 0 };
				
				while( c = sread[k] )
				{
					if( c == '/' || c == ' ' || c == '\n' )
					{
						if( face >= sizeof( params ) / sizeof( params[0] ) )
						{
							fprintf( stderr, "Error on line %d\n", lineno );
							continue;
						}
						int r = sscanf( sread + s, "%d", &params[face][pB] );
						s = k + 1;
						if( r != 1 )
						{
							fprintf( stderr, "Error on line %d\n", lineno );
						}
					}
					if( c == '/' )
					{
						pB++;
						if( pB > maxE ) maxE = pB;
					}
					if( c == ' ' || c == '\n' )
					{
						pB = 0;
						face ++;
					}
					
					k++;
				}
				
				if( mode == 1 )
				{
					if( face < 3 )
					{
						fprintf( stderr, "Error: Can't have < 3 faces (Got %d). Error on line %d\n", face, lineno );
						thisPlace = 0;
						continue;
					}
					fprintf( fOut, "\t" );
					WriteVertex1( fOut, params[0] );
					WriteVertex1( fOut, params[1] );
					WriteVertex1( fOut, params[2] );
					oTris++;
					int e;
					for( e = 3; e < face; e++ )
					{
						WriteVertex1( fOut, params[0] );
						WriteVertex1( fOut, params[e-1] );
						WriteVertex1( fOut, params[e] );
						oTris++;
					}
					fprintf( fOut, "\n" );
				}
			}
			
			thisPlace = 0;
			lineno++;
		}
		else if( thisPlace < sizeof(thisLine)-1 )
		{
			thisLine[thisPlace++] = c;
		}	
	} while( 1 );
	fprintf( fOut, "};\n\nint %s_Tris = %d;\nint %s_Mode = %d;\n", argv[3], oTris, argv[3], mode );
	return 0;
}

/*
# Blender 4.1.1
# www.blender.org
mtllib pistol.mtl
o group1710519388
v -0.000261 0.017268 0.144238 0.9960 0.6039 0.4118
v -0.009009 0.015129 0.144189 0.9882 0.5843 0.4353
...
f 191 187 185
f 199 195 191
*/