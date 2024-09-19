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
} __attribute__((packed));

static inline void pcont(void) { asm volatile( ".word 0x02100073" : : : "memory" ); }

typedef uint32_t HIDMatrix[4][4];

struct HardwareInput
{
	uint32_t PointerX;
	uint32_t PointerY;
	uint32_t PointerZ;
	uint32_t res;
	uint32_t PointerX2;
	uint32_t PointerY2;
	uint32_t PointerZ2;
	uint32_t res2;
	uint32_t TimeMS;
	uint32_t TriggerLeft;
	uint32_t TriggerRight;
	uint32_t res5;
	uint32_t res6[4];
	HIDMatrix Screen;
	HIDMatrix GunBack;
	HIDMatrix GunTip;
};

#define HID ((struct HardwareInput*)0xf0000000)

#endif

#endif
