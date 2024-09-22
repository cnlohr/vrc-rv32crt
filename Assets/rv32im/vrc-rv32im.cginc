#ifndef VRC_RV32IMA
#define VRC_RV32IMA

#define MAXICOUNT    1023
#define MAX_FCNT     120
#define CACHE_BLOCKS 128
#define CACHE_N_WAY  4

Texture2D<uint4> _FlashMemory;
float4 _FlashMemory_TexelSize;

#define CRTTEXTURETYPE uint4

#include "/Assets/flexcrt/flexcrt.cginc"

//#define COMPUTE_OUT_X 256
//#define COMPUTE_OUT_Y 256

//XXX NOTE: Optimization: May want to hard-code this.

#define SYSTEX_SIZE_X (uint)(_SelfTexture2D_TexelSize.z)
#define SYSTEX_SIZE_Y (uint)(_SelfTexture2D_TexelSize.w)

/* Memory Map 
	0x10000000 to 0x12000000 - Special I/O
	0x80000000 to 0x9fffffff - Flash  (Up to 512MB, but limited to real data.)
	0xa0000000 to 0xbfffffff - RAM    (Up to 512MB, but practically, limited.)
		To be clear - the actual size of RAM in the .lds (linker script) and the CRT MUST match so we know where to put the stack.
*/


// Farsical memory size, mostly so we can deal with whatever in the cache system. (Was (SYSTEX_SIZE_X*SYSTEX_SIZE_Y*16 - SYSTEX_SIZE_X*16) )
#define MINI_RV32_RAM_SIZE 0x40000000 //Ram + Flash
#define MEMORY_SIZE (MINI_RV32_RAM_SIZE)
#define MINIRV32_RAM_IMAGE_OFFSET  0x80000000
#define MEMORY_SPLIT 0x20000000

// Cores only take 13 uint4's, but, we should pretend they take a whole line to provide a short-cut stack, or processor-local data.
// Processor state takes up 208 bytes.
#define CORESPHY 32
#define CORESHYPER 2
#define CORES (CORESHYPER * CORESPHY)

float4 _GeneralArray[1023];
float4 _PlayerArray[1023];
float4 _BoneArray[1023];


// For intermediate outputs.
static uint pixelOutputID;

float4 ClipSpaceCoordinateOut( uint2 coordOut, float2 FlexCRTSize )
{
	// I believe these are equivelent. 
	//return float4((coordOut.xy*float2(2,-2)+float2(-2.0*FlexCRTSize.x*0.5+1.5,FlexCRTSize.y-1.5))/FlexCRTSize, 0.5, 1 );
	return float4( coordOut.xy*float2(1,-1)+float2(-FlexCRTSize.x/2+.5,FlexCRTSize.y/2-.5), 0, FlexCRTSize.x/2 );
}

#define MINIRV32_IMPLEMENTATION
#define MINIRV32WARN( x )
#define MINIRV32_POSTEXEC( pc, ir, trap )

#define MINIRV32_OTHERCSR_WRITE( csrno, writeval ) 
	//if( csrno == 0x139 ) { state[charout] = writeval; icount = MAXICOUNT; }
#define MINIRV32_OTHERCSR_READ( csrno, rval ) rval = 0;
#define MINIRV32_STATE_DEFINTION inout uint state[52], 

// Not used on avatars.
uint GetHostInfo( uint rsval )
{
	uint pos = ((rsval)>>4) & 0x3ff;
	uint select = (rsval>>2) & 0x3;
	uint shift = ((rsval) & 0x3)*8;
	float4 v = 0;
	if( rsval < 0x1000 )
		v = _GeneralArray[pos];
	else if( rsval < 0x8000 )
		v = _PlayerArray[pos];
	else if( rsval < 0xc000 )
		v = _BoneArray[pos];

	return uint( int(v[select]))>>shift;
}
 
#define MINIRV32_HANDLE_MEM_STORE_CONTROL( addy, rs2 ) if( addy == 0x10000010 ) { state[advanceddescriptor] = rs2; icount = MAXICOUNT; } else if( addy == 0x11000000 ) { if( rs2 == 1 ) icount = MAXICOUNT; } 
#define MINIRV32_HANDLE_MEM_LOAD_CONTROL( rsval, rval ) rval = (rsval == 0x10000005) ? 0x60 : ( rsval >= 0x11200000 && rsval < 0x11210000 ) ? GetHostInfo( rsval - 0x11200000 ) : 0x00

//( rsval == 0x1100bff8 ) ? 12 : ( rsval == 0x1100bffc ) ? 34 : 0x00;

#define MINIRV32_CUSTOM_INTERNALS
#define MINIRV32_CUSTOM_STATE

#define pcreg 32
#define mstatus 33
#define cyclel 34
#define cycleh 35
#define timerl 36
#define timerh 37
#define timermatchl 38
#define timermatchh 39
#define mscratch 40
#define mtvec 41
#define mie 42
#define mip 43
#define mepc 44
#define mtval 45
#define mcause 46
#define extraflags 47

#define UNUSED 48 /* Unused */
//#define charout 49
#define advanceddescriptor 49
#define cpucounter 50
#define scratch00 51

#define CSR( x ) state[x]
#define SETCSR( x, val ) { state[x] = val; }
#define REG( x ) state[x]
#define REGSET( x, val ) { state[x] = val; }

#define uint32_t uint
#define int32_t  int

#define INT32_MIN -2147483648
#define AS_SIGNED(val) (asint(val))
#define AS_UNSIGNED(val) (asuint(val))

#define MainSystemAccess( blockno ) _SelfTexture2D[uint2( (blockno) % SYSTEX_SIZE_X, (blockno) / SYSTEX_SIZE_X)]
#define FlashSystemAccess( blockno ) _FlashMemory[uint2( (blockno) % uint(_FlashMemory_TexelSize.z), (blockno) / uint(_FlashMemory_TexelSize.z))]
#define MINIRV32_STEPPROTO MINIRV32_DECORATE int32_t MiniRV32IMAStep( MINIRV32_STATE_DEFINTION uint32_t elapsedUs )

static uint count;

#define uint4assign( x, y ) x = y


// Used for debugging

#include "/Packages/com.llealloo.audiolink/Runtime/Shaders/SmoothPixelFont.cginc"

float PrintHex2( uint val, float2 uv )
{
	uv.x = 1.0 - uv.x;
	uv *= float2( 8, 7 );
	int charno = uv.x/4;
	int row = uv.y/7;
	uint dig = (val >> (4-charno*4))&0xf;
	return PrintChar( (dig<10)?(dig+48):(dig+87), float2( charno*4-uv.x+4, uv.y-row*7 ), 2.0/(length( ddx( uv ) ) + length( ddy( uv ) )), 0.0);
}
float PrintHex8( uint4 val, float2 uv )
{
	uv *= float2( 32, 7*4 );
	int charno = uv.x/4;
	int row = uv.y/7;
	uint dig = (val[3-(row&3)] >> (28-charno*4))&0xf;
	return PrintChar( (dig<10)?(dig+48):(dig+87), float2( charno*4-uv.x+4, uv.y-row*7 ), 2.0/(length( ddx( uv ) ) + length( ddy( uv ) )), 0.0);
}



#endif
