#ifndef _VRCRV_H
#define _VRCRV_H

#define PCONT	.word 0x02100073


#ifndef __ASSEMBLER__

struct Hardware
{
	uint32_t termsizeX;
	uint32_t termsizeY;
	uint32_t termscrollX;
	uint32_t termscrollY;
	uint32_t * termdata;
	uint32_t res0[3];

	uint32_t backscreenX;
	uint32_t backscreenY;
	uint32_t backscreenSX;
	uint32_t backscreenSY;
	uint32_t * backscreendata;
	uint32_t res1[3];
};

static inline void pcont(void) { asm volatile( ".word 0x02100073" : : : "memory" ); }

#define EXTCAM ((uint32_t*)0xf0000000)

#endif

#endif
