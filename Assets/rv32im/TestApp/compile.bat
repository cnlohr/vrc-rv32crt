riscv64-unknown-elf-gcc -T vrc-rv32im.lds  -Wl,--gc-sections -Wl,--print-memory-usage  -nostdlib -static-libgcc -ffunction-sections -fdata-sections -flto -march=rv32im -mabi=ilp32  test.S test.c -o test.elf
riscv64-unknown-elf-objdump -S test.elf > test.lst
riscv64-unknown-elf-objdump -t test.elf > test.map
riscv64-unknown-elf-objcopy -O binary test.elf test.bin

tcc imageify.c -o imageify.exe
imageify.exe test.bin test.png