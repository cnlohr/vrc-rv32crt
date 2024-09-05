.global InterruptVector
.section .init
InterruptVector:
	j _start
	j _interrupttest
	
_interrupttest:
	j _interrupttest
	
_start:
	// a0 = hart ID
	// a1 = DTB, normally, not used in this setup I guess,.

	li a3, 0x012abcdef
	j main

_loop:
	j _loop