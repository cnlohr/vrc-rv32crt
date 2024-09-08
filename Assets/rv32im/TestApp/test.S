// Exports

.global InterruptVector

.section .bss
.global hartid
hartid:
	.word 0x00000000

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

	la sp, _eusrstack
	li a3, 0x80
	csrw mstatus, a3
	
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

	la a3, hartid
	sw a0, 0(a3)

	la a3, 0x10000010
	la a4, hardwaredef
	sw a4, 0(a3)
	
	la a4, main
	ori a7, a4, 0
	csrw mepc, a4
	mret
