# AkromOS

Operating system sederhana yang ditulis dalam Assembly dan C untuk arsitektur x86 (32-bit).

## Tampilan awal
<img width="1366" height="768" alt="swappy-20260113-023918" src="https://github.com/user-attachments/assets/a4225bdf-ae60-43c9-b0f7-bd14d9f7d362" />

## Fitur

- **Bootloader kustom** (512 bytes) yang memuat kernel dari disk
- **Protected mode** (32-bit)
- **VGA text mode** dengan dukungan warna
- **Shell interaktif** sederhana dengan command handling
- **Keyboard input** (polling mode)

## Struktur File

```
AkromOS/
├── boot.asm           # Bootloader (16-bit real mode → 32-bit protected mode)
├── kernel_entry.asm   # Entry point kernel
├── kernel.c           # Kernel utama (C)
├── linker.ld          # Linker script
├── Makefile           # Build script
└── README.md          # Dokumentasi ini
etc
```

## Requirement

### Tools yang dibutuhkan:

- **NASM** (Netwide Assembler)
- **GCC** dengan dukungan cross-compilation untuk i686
- **LD** (GNU Linker)
- **QEMU** (untuk testing/emulasi)
- **Make**

### Install di Arch Linux:

```bash
sudo pacman -S nasm gcc ld qemu-system-x86 make
```

Jika perlu cross-compiler:
```bash
sudo pacman -S i686-elf-gcc i686-elf-binutils
```

## Build Instructions
```bash
cd ~/your/path/AkromOS
nasm -f bin boot.asm -o boot.bin 
nasm -f bin kernel_simple.asm -o kernel_simple.bin
cat boot.bin kernel_simple.bin > akromos.img
truncate -s 1474560 akromos.img
qemu-system-i386 -fda akromos.img
```
## Commands yang tersedia

Setelah boot, AkromOS akan menampilkan shell prompt (`$`). Commands yang tersedia:

- `help` - Menampilkan daftar command
- `clear` - Clear screen
- `about` - Informasi tentang AkromOS
- `echo [text]` - Echo text yang diinput

## Cara Kerja

### Boot Process:

1. **BIOS** memuat bootloader (boot.asm) ke memori 0x7C00
2. **Bootloader** memuat kernel dari disk sector 2-11 ke memori 0x1000
3. **Enable A20 line** untuk akses memori extended
4. **Load GDT** (Global Descriptor Table)
5. **Switch ke protected mode** (32-bit)
6. **Jump ke kernel entry point** (kernel_entry.asm)
7. **Kernel** memanggil fungsi `kmain()` di kernel.c
8. **Shell** dimulai dan menunggu input user

### Memory Layout:

```
0x00000000 - 0x000003FF : Interrupt Vector Table
0x00000400 - 0x000004FF : BIOS Data Area
0x00007C00 - 0x00007DFF : Bootloader (512 bytes)
0x00001000 - 0x0000FFFF : Kernel
0x000B8000 - 0x000BFFFF : VGA Text Buffer
0x00090000 - ...        : Stack
```

## Troubleshooting

### Error: `command not found`
Pastikan semua tools sudah terinstall (nasm, gcc, ld, make, qemu).

### Error saat compile dengan GCC
Gunakan flag `-m32` dan pastikan GCC mendukung 32-bit compilation:
```bash
gcc -m32 --version
```

Jika tidak support, install `gcc-multilib` atau gunakan cross-compiler `i686-elf-gcc`.

### OS tidak boot di QEMU
- Pastikan `AkromOS.img` terbuat dengan benar
- Cek bootloader signature (0xAA55) ada di byte terakhir boot sector
- Jalankan dengan `-d int` untuk debug: `qemu-system-i386 -fda AkromOS.img -d int`

## Pengembangan Lanjutan

Ideas untuk pengembangan:

- Implementasi interrupt handlers (IDT)
- Memory management (paging, heap allocation)
- Filesystem driver (FAT12/FAT16)
- Multi-tasking / process management
- Device drivers (timer, disk, network)
- System calls
- User mode programs

## Resources

- [OSDev Wiki](https://wiki.osdev.org/)
- [Intel x86 Manual](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html)
- [Bran's Kernel Development Tutorial](http://www.osdever.net/bkerndev/index.php)

## License

Free to use and modify for educational purposes.

---

**AkromOS v1.0** - A minimal operating system for learning OS development
