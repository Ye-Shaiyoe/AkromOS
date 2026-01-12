
[BITS 32]
[EXTERN kmain]

global _start

_start:
    call kmain
    
    jmp $
