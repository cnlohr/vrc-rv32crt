#ifndef _VRCRV_H
#define _VRCRV_H

#define PCONT	.word 0x02100073

// All hardware-accelerated structures must be 128-bit aligned.
#define ALIGN __attribute__((aligned(16)))

#ifndef __ASSEMBLER__

#define MAX_HOLO_OBJECTS 256
#define MAX_HOLO_TVPEROBJECT 128

struct holoTransform
{
	union
	{
		struct holoTransQuat
		{
			int32_t tX, tY, tZ, S;
			int32_t qW, qX, qY, qZ;
		} __attribute__((packed)) tq;

		struct holoTransEuler
		{
			int32_t tX, tY, tZ, S;
			int32_t rX, rY, rZ, res;
		} __attribute__((packed)) te;
	};
} __attribute__((packed));

struct holoSteamObject
{
	uint16_t nNumberOfTriangles;
	uint8_t nMode;
	uint8_t nReserved;

	uint8_t nTransMode0;
	uint8_t nTransMode1;
	uint8_t nTransMode2;
	uint8_t nTransMode3;
	
	uint32_t nReserved1;
	uint32_t nReserved2;

	const uint32_t * pTriangleList;
	const uint32_t * pReserved1; // UNUSED
	const uint32_t * pReserved2; // UNUSED
	const uint32_t * pReserved3; // UNUSED
	
	struct holoTransform * pXform0;
	struct holoTransform * pXform1;
	struct holoTransform * pXform2;
	struct holoTransform * pXform3;
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
