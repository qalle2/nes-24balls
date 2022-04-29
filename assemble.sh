# Note: this script will DELETE files. Use at your own risk.

rm -f *.bin *.cdl *.gz *.nes *.nl
python3 ../nes-util/nes_chr_encode.py chr.png chr.bin
asm6 24balls.asm 24balls.nes
gzip --best -k *.bin *.nes
