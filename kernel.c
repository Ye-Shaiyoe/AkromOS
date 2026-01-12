// kernel.c - Kernel utama AkromOS

#define VGA_ADDRESS 0xB8000
#define VGA_WIDTH 80
#define VGA_HEIGHT 25

// VGA Color codes
#define BLACK 0
#define BLUE 1
#define GREEN 2
#define CYAN 3
#define RED 4
#define MAGENTA 5
#define BROWN 6
#define LIGHT_GRAY 7
#define DARK_GRAY 8
#define LIGHT_BLUE 9
#define LIGHT_GREEN 10
#define LIGHT_CYAN 11
#define LIGHT_RED 12
#define LIGHT_MAGENTA 13
#define YELLOW 14
#define WHITE 15

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned int uint32_t;

static uint16_t* vga_buffer = (uint16_t*)VGA_ADDRESS;
static uint32_t cursor_x = 0;
static uint32_t cursor_y = 0;

// Port I/O functions
static inline void outb(uint16_t port, uint8_t val) {
    asm volatile("outb %0, %1" : : "a"(val), "Nd"(port));
}

static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    asm volatile("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

// Buat karakter dengan warna
uint16_t make_vga_entry(char c, uint8_t fg, uint8_t bg) {
    uint8_t color = (bg << 4) | (fg & 0x0F);
    return (uint16_t)c | ((uint16_t)color << 8);
}

// Clear screen
void clear_screen() {
    for (uint32_t i = 0; i < VGA_WIDTH * VGA_HEIGHT; i++) {
        vga_buffer[i] = make_vga_entry(' ', WHITE, BLUE);
    }
    cursor_x = 0;
    cursor_y = 0;
}

// Update hardware cursor
void update_cursor() {
    uint16_t pos = cursor_y * VGA_WIDTH + cursor_x;
    outb(0x3D4, 0x0F);
    outb(0x3D5, (uint8_t)(pos & 0xFF));
    outb(0x3D4, 0x0E);
    outb(0x3D5, (uint8_t)((pos >> 8) & 0xFF));
}

// Print character
void putchar(char c, uint8_t fg, uint8_t bg) {
    if (c == '\n') {
        cursor_x = 0;
        cursor_y++;
    } else if (c == '\t') {
        cursor_x = (cursor_x + 4) & ~(4 - 1);
    } else {
        uint32_t index = cursor_y * VGA_WIDTH + cursor_x;
        vga_buffer[index] = make_vga_entry(c, fg, bg);
        cursor_x++;
    }

    if (cursor_x >= VGA_WIDTH) {
        cursor_x = 0;
        cursor_y++;
    }

    // Scroll jika sudah di bawah
    if (cursor_y >= VGA_HEIGHT) {
        for (uint32_t i = 0; i < (VGA_HEIGHT - 1) * VGA_WIDTH; i++) {
            vga_buffer[i] = vga_buffer[i + VGA_WIDTH];
        }
        for (uint32_t i = (VGA_HEIGHT - 1) * VGA_WIDTH; i < VGA_HEIGHT * VGA_WIDTH; i++) {
            vga_buffer[i] = make_vga_entry(' ', WHITE, BLUE);
        }
        cursor_y = VGA_HEIGHT - 1;
    }

    update_cursor();
}

// Print string
void print(const char* str, uint8_t fg, uint8_t bg) {
    for (uint32_t i = 0; str[i] != '\0'; i++) {
        putchar(str[i], fg, bg);
    }
}

// Print string dengan warna default
void println(const char* str) {
    print(str, WHITE, BLUE);
    putchar('\n', WHITE, BLUE);
}

// String length
uint32_t strlen(const char* str) {
    uint32_t len = 0;
    while (str[len]) len++;
    return len;
}

// Memory compare
int memcmp(const void* s1, const void* s2, uint32_t n) {
    const uint8_t* p1 = (const uint8_t*)s1;
    const uint8_t* p2 = (const uint8_t*)s2;
    for (uint32_t i = 0; i < n; i++) {
        if (p1[i] != p2[i]) return p1[i] - p2[i];
    }
    return 0;
}

// Simple shell command handler
void handle_command(const char* cmd) {
    if (memcmp(cmd, "help", 4) == 0) {
        println("Available commands:");
        println("  help  - Show this help");
        println("  clear - Clear screen");
        println("  about - About AkromOS");
        println("  echo  - Echo text");
    } else if (memcmp(cmd, "clear", 5) == 0) {
        clear_screen();
        print("AkromOS v1.0", LIGHT_CYAN, BLUE);
        println(" > Type 'help' for commands");
    } else if (memcmp(cmd, "about", 5) == 0) {
        println("AkromOS v1.0");
        println("A simple operating system written in Assembly and C");
        println("Architecture: x86 (32-bit)");
    } else if (memcmp(cmd, "echo ", 5) == 0) {
        println(cmd + 5);
    } else if (strlen(cmd) > 0) {
        print("Unknown command: ", LIGHT_RED, BLUE);
        println(cmd);
    }
}

// Keyboard handler (polling mode - simple)
char getchar() {
    uint8_t scancode;
    
    // Wait for key
    while (!(inb(0x64) & 1));
    
    scancode = inb(0x60);
    
    // Simple scancode to ASCII mapping (US keyboard)
    static const char scancode_to_ascii[] = {
        0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', '\b',
        '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
        0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
        0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*',
        0, ' '
    };
    
    if (scancode < sizeof(scancode_to_ascii)) {
        return scancode_to_ascii[scancode];
    }
    
    return 0;
}

// Simple shell
void shell() {
    char buffer[256];
    uint32_t index = 0;
    
    print("$ ", YELLOW, BLUE);
    
    while (1) {
        char c = getchar();
        
        if (c == '\n') {
            putchar('\n', WHITE, BLUE);
            buffer[index] = '\0';
            handle_command(buffer);
            index = 0;
            print("$ ", YELLOW, BLUE);
        } else if (c == '\b') {
            if (index > 0) {
                index--;
                cursor_x--;
                putchar(' ', WHITE, BLUE);
                cursor_x--;
                update_cursor();
            }
        } else if (c != 0 && index < 255) {
            buffer[index++] = c;
            putchar(c, WHITE, BLUE);
        }
    }
}

// Kernel main function
void kmain() {
    clear_screen();
    
    // Print header
    print("====================================", LIGHT_CYAN, BLUE);
    println("");
    print("       Welcome to AkromOS v1.0     ", LIGHT_GREEN, BLUE);
    println("");
    print("====================================", LIGHT_CYAN, BLUE);
    println("");
    println("");
    
    print("System initialized successfully!", LIGHT_GREEN, BLUE);
    println("");
    print("Type 'help' for available commands", LIGHT_GRAY, BLUE);
    println("");
    println("");
    
    // Start shell
    shell();
    
    // Infinite loop (shouldn't reach here)
    while (1) {
        asm("hlt");
    }
}
