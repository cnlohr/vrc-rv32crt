// Exports

#include "vrcrv.h"

.global InterruptVector

.section .bss

.section .init
InterruptVector:
	j _start
	j _interrupttest
	
_interrupttest:
	j _interrupttest
	
_start:
	// a0 = hart ID
	// a1 = DTB, normally, not used in this setup I guess,.

.option push
.option norelax
	la gp, __global_pointer$
.option pop


	li a3, 0x80
	csrw mstatus, a3

	bnez a0, not_processor_zero
	la sp, _eusrstack
	
	// Test writing to RAM.
	//la a3, 0xa0000000
	//sw a4, 0(a3)

	// This clears BSS (We dont need to do this)
#if 0
	la a3, _sbss
	la a4, _ebss
	li a5, 0
	bge a3, a4, 2f
1:	sw a5, 0(a3)
	addi a3, a3, 4
	blt a3, a4, 1b
2:
#endif

	// This loads DATA from FLASH to RAM.
	la a3, _data_lma
	la a4, _data_vma
	la a5, _edata
1:	beq a4, a5, 2f
	lw a7, 0(a3)
	sw a7, 0(a4)
	addi a3, a3, 4
	addi a4, a4, 4
	bne a4, a5, 1b
2:

	la a3, 0x10000010
	la a4, hardwaredef
	sw a4, 0(a3)
	
	la a4, main
	ori a7, a4, 0
	csrw mepc, a4
	mret

not_processor_zero:
	// Other processors dont have a stack or anything...

	la a3, hardwaredef
1:
	lw a7, 48(a3)
	beqz a7, 1b

	la a4, otherharts
	ori a7, a4, 0
	csrw mepc, a4
	mret

	
/*	
	// A7 contains the pointer to the back buffer now.
	slli a1, a0, 6
	add a7, a7, a1
	
	li a6, '0'
	add a6, a0, a6
	sw a6, 0(a7)
	sw a6, 4(a7)
	sw a6, 8(a7)
	sw a6, 12(a7)

1:
	//PCONT
	j 1b
*/