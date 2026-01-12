; kernel_simple.asm - Kernel dengan Timer Interrupt & Clock
[BITS 32]
[ORG 0x1000]

start:
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Setup IDT
    call setup_idt

    ; Setup PIC (Programmable Interrupt Controller)
    call setup_pic

    ; Setup PIT (Programmable Interval Timer) - 100 Hz
    call setup_pit

    ; Enable interrupts
    sti

    ; Clear screen dengan warna biru
    call clear_screen

    ; Print welcome message
    mov esi, msg_welcome
    mov bl, 0x1F
    call print_string

    mov esi, msg_line
    mov bl, 0x13
    call print_string

    mov esi, msg_success
    mov bl, 0x1A
    call print_string

    mov esi, msg_help
    mov bl, 0x17
    call print_string

    ; Print prompt
    call print_prompt

    ; Main loop - just update clock and halt
main_loop:
    ; Update clock display
    call update_clock_display
    
    ; Check if we have a key in buffer
    mov al, [key_buffer]
    cmp al, 0
    je .no_key
    
    ; Process the key
    mov byte [key_buffer], 0  ; Clear buffer
    
    ; Handle backspace
    cmp al, 0x08
    je handle_backspace
    
    ; Handle enter
    cmp al, 0x0D
    je handle_enter
    
    ; Print character if printable
    cmp al, 0x20
    jl .no_key
    cmp al, 0x7E
    jg .no_key
    
    ; Store in buffer
    mov edi, [buffer_pos]
    cmp edi, 255
    jge .no_key
    mov [input_buffer + edi], al
    inc dword [buffer_pos]
    
    ; Print character
    mov bl, 0x1F
    call print_char

.no_key:
    ; Halt until next interrupt
    hlt
    jmp main_loop

handle_backspace:
    mov edi, [buffer_pos]
    cmp edi, 0
    je main_loop
    dec dword [buffer_pos]
    
    mov eax, [cursor_pos]
    sub eax, 2
    mov [cursor_pos], eax
    
    mov al, ' '
    mov bl, 0x1F
    call print_char
    
    mov eax, [cursor_pos]
    sub eax, 2
    mov [cursor_pos], eax
    jmp main_loop

handle_enter:
    mov edi, [buffer_pos]
    mov byte [input_buffer + edi], 0
    
    call new_line
    call process_command
    
    mov dword [buffer_pos], 0
    call print_prompt
    jmp main_loop

; ========== IDT Setup ==========
setup_idt:
    pushad
    
    ; Load IDT
    lidt [idt_descriptor]
    
    ; Setup timer interrupt (IRQ0 -> INT 0x20)
    mov edi, idt + (0x20 * 8)
    mov eax, timer_interrupt
    mov [edi], ax
    shr eax, 16
    mov [edi + 6], ax
    mov word [edi + 2], 0x08  ; Code segment
    mov byte [edi + 4], 0
    mov byte [edi + 5], 0x8E  ; Present, DPL=0, 32-bit interrupt gate
    
    ; Setup keyboard interrupt (IRQ1 -> INT 0x21)
    mov edi, idt + (0x21 * 8)
    mov eax, keyboard_interrupt
    mov [edi], ax
    shr eax, 16
    mov [edi + 6], ax
    mov word [edi + 2], 0x08
    mov byte [edi + 4], 0
    mov byte [edi + 5], 0x8E
    
    popad
    ret

; ========== PIC Setup ==========
setup_pic:
    pushad
    
    ; ICW1 - Start initialization
    mov al, 0x11
    out 0x20, al
    out 0xA0, al
    
    ; ICW2 - Interrupt vectors
    mov al, 0x20  ; Master PIC: IRQ 0-7 -> INT 0x20-0x27
    out 0x21, al
    mov al, 0x28  ; Slave PIC: IRQ 8-15 -> INT 0x28-0x2F
    out 0xA1, al
    
    ; ICW3 - Cascading
    mov al, 0x04  ; Master: slave at IRQ2
    out 0x21, al
    mov al, 0x02  ; Slave: cascade identity
    out 0xA1, al
    
    ; ICW4 - Mode
    mov al, 0x01  ; 8086 mode
    out 0x21, al
    out 0xA1, al
    
    ; Unmask IRQ0 (timer) and IRQ1 (keyboard)
    mov al, 0xFC  ; 11111100 - enable IRQ0 and IRQ1
    out 0x21, al
    mov al, 0xFF  ; Mask all slave PIC interrupts
    out 0xA1, al
    
    popad
    ret

; ========== PIT Setup (100 Hz) ==========
setup_pit:
    pushad
    
    ; Channel 0, lobyte/hibyte, rate generator
    mov al, 0x36
    out 0x43, al
    
    ; Set frequency to 100 Hz (1193182 / 100 = 11931 = 0x2E9B)
    mov al, 0x9B
    out 0x40, al
    mov al, 0x2E
    out 0x40, al
    
    popad
    ret

; ========== Timer Interrupt Handler ==========
timer_interrupt:
    pushad
    
    ; Increment tick counter
    inc dword [timer_ticks]
    
    ; Update time (100 ticks = 1 second)
    mov eax, [timer_ticks]
    cmp eax, 100
    jl .done
    
    ; Reset ticks
    mov dword [timer_ticks], 0
    
    ; Increment seconds
    inc byte [clock_seconds]
    cmp byte [clock_seconds], 60
    jl .done
    
    ; Reset seconds, increment minutes
    mov byte [clock_seconds], 0
    inc byte [clock_minutes]
    cmp byte [clock_minutes], 60
    jl .done
    
    ; Reset minutes, increment hours
    mov byte [clock_minutes], 0
    inc byte [clock_hours]
    cmp byte [clock_hours], 24
    jl .done
    
    ; Reset hours
    mov byte [clock_hours], 0

.done:
    ; Send EOI to PIC
    mov al, 0x20
    out 0x20, al
    
    popad
    iret

; ========== Keyboard Interrupt Handler ==========
keyboard_interrupt:
    pushad
    
    ; Read scancode
    in al, 0x60
    
    ; Check if key release (bit 7 set)
    test al, 0x80
    jnz .done
    
    ; Convert scancode to ASCII
    movzx ebx, al
    cmp ebx, 128
    jge .done
    
    mov al, [scancode_table + ebx]
    cmp al, 0
    je .done
    
    ; Store in key buffer (only if buffer is empty)
    cmp byte [key_buffer], 0
    jne .done
    mov [key_buffer], al

.done:
    ; Send EOI
    mov al, 0x20
    out 0x20, al
    
    popad
    iret

; ========== Update Clock Display ==========
update_clock_display:
    pushad
    
    ; Save current cursor position
    mov eax, [cursor_pos]
    push eax
    
    ; Position: top-right corner (row 0, col 70)
    mov dword [cursor_pos], (0 * 160) + (70 * 2)
    
    ; Print hours
    movzx eax, byte [clock_hours]
    call print_number
    mov al, ':'
    mov bl, 0x1E
    call print_char
    
    ; Print minutes
    movzx eax, byte [clock_minutes]
    call print_number
    mov al, ':'
    mov bl, 0x1E
    call print_char
    
    ; Print seconds
    movzx eax, byte [clock_seconds]
    call print_number
    
    ; Restore cursor position
    pop eax
    mov [cursor_pos], eax
    
    popad
    ret

; ========== Print 2-digit Number ==========
print_number:
    pushad
    push eax
    
    ; Tens digit
    xor edx, edx
    mov ebx, 10
    div ebx
    add al, '0'
    mov bl, 0x1E
    call print_char
    
    ; Ones digit
    pop eax
    xor edx, edx
    mov ebx, 10
    div ebx
    mov al, dl
    add al, '0'
    mov bl, 0x1E
    call print_char
    
    popad
    ret

; ========== Process Command ==========
process_command:
    pushad
    
    mov edi, [buffer_pos]
    cmp edi, 0
    je .done
    
    ; Check for "help"
    mov esi, input_buffer
    mov edi, cmd_help
    call strcmp
    cmp eax, 0
    je .cmd_help
    
    ; Check for "clear"
    mov esi, input_buffer
    mov edi, cmd_clear
    call strcmp
    cmp eax, 0
    je .cmd_clear
    
    ; Check for "about"
    mov esi, input_buffer
    mov edi, cmd_about
    call strcmp
    cmp eax, 0
    je .cmd_about
    
    ; Check for "time"
    mov esi, input_buffer
    mov edi, cmd_time
    call strcmp
    cmp eax, 0
    je .cmd_time
    
    ; Check for "uptime"
    mov esi, input_buffer
    mov edi, cmd_uptime
    call strcmp
    cmp eax, 0
    je .cmd_uptime
    
    ; Unknown command
    mov esi, msg_unknown
    mov bl, 0x1C
    call print_string
    mov esi, input_buffer
    mov bl, 0x1C
    call print_string
    call new_line
    jmp .done

.cmd_help:
    mov esi, help_text
    mov bl, 0x1F
    call print_string
    jmp .done

.cmd_clear:
    call clear_screen
    mov esi, msg_cleared
    mov bl, 0x1A
    call print_string
    jmp .done

.cmd_about:
    mov esi, about_text
    mov bl, 0x1B
    call print_string
    jmp .done

.cmd_time:
    mov esi, msg_time_label
    mov bl, 0x1F
    call print_string
    
    movzx eax, byte [clock_hours]
    call print_number
    mov al, ':'
    mov bl, 0x1F
    call print_char
    
    movzx eax, byte [clock_minutes]
    call print_number
    mov al, ':'
    mov bl, 0x1F
    call print_char
    
    movzx eax, byte [clock_seconds]
    call print_number
    call new_line
    jmp .done

.cmd_uptime:
    mov esi, msg_uptime_label
    mov bl, 0x1F
    call print_string
    
    ; Calculate total seconds
    movzx eax, byte [clock_hours]
    mov ebx, 3600
    mul ebx
    mov edi, eax
    
    movzx eax, byte [clock_minutes]
    mov ebx, 60
    mul ebx
    add edi, eax
    
    movzx eax, byte [clock_seconds]
    add edi, eax
    
    ; Print total seconds
    mov eax, edi
    call print_decimal
    
    mov esi, msg_seconds
    mov bl, 0x1F
    call print_string
    jmp .done

.done:
    popad
    ret

; ========== Print Decimal Number ==========
print_decimal:
    pushad
    
    ; Convert number to string
    mov ebx, 10
    xor ecx, ecx
    
.convert_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    push edx
    inc ecx
    test eax, eax
    jnz .convert_loop
    
.print_loop:
    pop eax
    mov bl, 0x1F
    call print_char
    loop .print_loop
    
    popad
    ret

; ========== String Compare ==========
strcmp:
    push esi
    push edi
.loop:
    mov al, [esi]
    mov bl, [edi]
    cmp al, bl
    jne .not_equal
    cmp al, 0
    je .equal
    inc esi
    inc edi
    jmp .loop
.equal:
    xor eax, eax
    pop edi
    pop esi
    ret
.not_equal:
    mov eax, 1
    pop edi
    pop esi
    ret

; ========== Clear Screen ==========
clear_screen:
    pushad
    mov edi, 0xB8000
    mov ecx, 80 * 25
    mov ax, 0x1F20
.loop:
    mov [edi], ax
    add edi, 2
    loop .loop
    mov dword [cursor_pos], 0
    popad
    ret

; ========== Print Character ==========
print_char:
    pushad
    movzx eax, al
    mov ah, bl
    mov edi, [cursor_pos]
    add edi, 0xB8000
    mov [edi], ax
    add dword [cursor_pos], 2
    popad
    ret

; ========== Print String ==========
print_string:
    pushad
.loop:
    lodsb
    cmp al, 0
    je .done
    cmp al, 10
    je .newline
    call print_char
    jmp .loop
.newline:
    call new_line
    jmp .loop
.done:
    popad
    ret

; ========== New Line ==========
new_line:
    pushad
    mov eax, [cursor_pos]
    xor edx, edx
    mov ebx, 160
    div ebx
    inc eax
    mul ebx
    mov [cursor_pos], eax
    popad
    ret

; ========== Print Prompt ==========
print_prompt:
    pushad
    mov esi, prompt
    mov bl, 0x1E
    call print_string
    popad
    ret

; ========== Data Section ==========
cursor_pos: dd 0
buffer_pos: dd 0
input_buffer: times 256 db 0

; Timer and clock data
timer_ticks: dd 0
clock_hours: db 0
clock_minutes: db 0
clock_seconds: db 0

; Keyboard buffer
key_buffer: db 0

prompt: db '$ ', 0
msg_welcome: db '====================================', 10
            db '   Welcome to AkromOS v1.1!', 10
            db '   [Timer Interrupt + Clock]', 10
            db '====================================', 10, 10, 0
msg_line: db '------------------------------------', 10, 0
msg_success: db 'System initialized successfully!', 10, 0
msg_help: db "Type 'help' for available commands", 10, 10, 0
msg_cleared: db 'Screen cleared!', 10, 0
msg_unknown: db 'Unknown command: ', 0
msg_time_label: db 'Current time: ', 0
msg_uptime_label: db 'Uptime: ', 0
msg_seconds: db ' seconds', 10, 0

cmd_help: db 'help', 0
cmd_clear: db 'clear', 0
cmd_about: db 'about', 0
cmd_time: db 'time', 0
cmd_uptime: db 'uptime', 0

help_text: db 'Available commands:', 10
          db '  help   - Show this help', 10
          db '  clear  - Clear screen', 10
          db '  about  - About AkromOS', 10
          db '  time   - Show current time', 10
          db '  uptime - Show system uptime', 10, 0

about_text: db 'AkromOS v1.1', 10
           db 'A simple OS with timer interrupts', 10
           db 'Architecture: x86 (32-bit)', 10
           db 'Features: IDT, PIC, PIT, Real-time clock', 10, 0

; Scancode to ASCII table
scancode_table:
    db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0x08, 0x09
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0x0D, 0
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\'
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*', 0, ' '
    times 128-($-scancode_table) db 0

; ========== IDT ==========
align 8
idt:
    times 256 * 8 db 0

idt_descriptor:
    dw 256 * 8 - 1
    dd idt

times 10240-($-$$) db 0
