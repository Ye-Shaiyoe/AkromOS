
; boot.asm - Bootloader sederhana
[BITS 16]
[ORG 0x7C00]

start:
    ; Setup segment registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Print loading message
    mov si, msg_loading
    call print_string

    ; Load kernel dari disk ke memori 0x1000
    mov bx, 0x1000      ; Destination address
    mov ah, 0x02        ; Read sectors function
    mov al, 10          ; Number of sectors to read
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Sector 2 (sector 1 adalah bootloader)
    mov dh, 0           ; Head 0
    int 0x13            ; BIOS disk interrupt
    
    jc disk_error       ; Jump if carry flag set (error)

    ; Enable A20 line
    call enable_a20

    ; Load GDT
    cli
    lgdt [gdt_descriptor]

    ; Switch to protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to 32-bit code
    jmp CODE_SEG:protected_mode

disk_error:
    mov si, msg_error
    call print_string
    jmp $

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

enable_a20:
    in al, 0x92
    or al, 2
    out 0x92, al
    ret

; GDT (Global Descriptor Table)
gdt_start:
    dq 0                ; Null descriptor

gdt_code:
    dw 0xFFFF           ; Limit
    dw 0                ; Base (low)
    db 0                ; Base (middle)
    db 10011010b        ; Access byte
    db 11001111b        ; Flags + Limit (high)
    db 0                ; Base (high)

gdt_data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0

gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

CODE_SEG equ gdt_code - gdt_start
DATA_SEG equ gdt_data - gdt_start

[BITS 32]
protected_mode:
    ; Setup segment registers untuk protected mode
    mov ax, DATA_SEG
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    
    mov esp, 0x90000    ; Setup stack

    ; Jump ke kernel C
    jmp 0x1000

msg_loading: db 'Loading AkromOS...', 13, 10, 0
msg_error: db 'Disk read error!', 13, 10, 0

times 510-($-$$) db 0
dw 0xAA55               ; Boot signature
