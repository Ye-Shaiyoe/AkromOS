# Makefile untuk AkromOS

# Tools
ASM = nasm
CC = gcc
LD = ld
OBJCOPY = objcopy

# Flags
ASMFLAGS = -f elf32
CFLAGS = -m32 -ffreestanding -nostdlib -nostdinc -fno-builtin -fno-stack-protector -nostartfiles -nodefaultlibs -Wall -Wextra -fno-pie -c
LDFLAGS = -m elf_i386 -T linker.ld --oformat binary -nostdlib

# Files
BOOT_BIN = boot.bin
KERNEL_BIN = kernel.bin
OS_IMAGE = akromos.img

# Object files
OBJS = kernel_entry.o kernel.o

all: $(OS_IMAGE)

# Build bootloader
$(BOOT_BIN): boot.asm
	$(ASM) -f bin boot.asm -o $(BOOT_BIN)

# Build kernel entry
kernel_entry.o: kernel_entry.asm
	$(ASM) $(ASMFLAGS) kernel_entry.asm -o kernel_entry.o

# Build kernel
kernel.o: kernel.c
	$(CC) $(CFLAGS) kernel.c -o kernel.o

# Link kernel
$(KERNEL_BIN): $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) -o $(KERNEL_BIN)

# Create OS image
$(OS_IMAGE): $(BOOT_BIN) $(KERNEL_BIN)
	cat $(BOOT_BIN) $(KERNEL_BIN) > $(OS_IMAGE)
	# Pad to floppy size (1.44MB)
	truncate -s 1474560 $(OS_IMAGE)

# Run in QEMU
run: $(OS_IMAGE)
	qemu-system-i386 -fda $(OS_IMAGE)

# Run in QEMU with debugging
debug: $(OS_IMAGE)
	qemu-system-i386 -fda $(OS_IMAGE) -s -S

# Clean build files
clean:
	rm -f *.o *.bin $(OS_IMAGE)

.PHONY: all run debug clean