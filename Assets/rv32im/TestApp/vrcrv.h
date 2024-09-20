#ifndef _VRCRV_H
#define _VRCRV_H

#define PCONT	.word 0x02100073


#ifndef __ASSEMBLER__

#define MAX_HOLO_OBJECTS 256
#define MAX_HOLO_TVPEROBJECT 128

struct holoTransform
{
	int32_t nX, nY, nZ, nS;
	int32_t qW, qX, qY, qZ;
} __attribute__((packed));

struct holoSteamObject
{
	uint32_t nNumberOfTriangles;
	uint32_t * pTriangleList;
	uint32_t * pReserved1; // UNUSED
	int nReserved1;        // UNUSED
	
	struct holoTransform * pXform1;
	uint32_t * pReserved2; // UNUSED
	struct holoTransform * pXform2;
	uint32_t * pReserved3; // UNUSED
} __attribute__((packed));

struct Hardware
{
	uint32_t nTermSizeX;
	uint32_t nTermSizeY;
	uint32_t nTermScrollX;
	uint32_t nTermScrollY;
	uint32_t * pTermData;
	uint32_t res0[3];

	uint32_t nBackscreenX;
	uint32_t nBackscreenY;
	uint32_t nBackscreenSX;
	uint32_t nBackscreenSY;
	uint32_t * pBackscreenData;
	uint32_t res1[3];
	
	// holostream matterator
	uint32_t res2[4];
	struct holoSteamObject * holostreamObjects[MAX_HOLO_OBJECTS];
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
