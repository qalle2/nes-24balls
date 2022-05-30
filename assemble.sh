# Note: this script will DELETE files. Use at your own risk.

rm -f *.cdl *.gz *.nes *.nl
asm6 24balls.asm 24balls.nes
python3 hexdump.py > hexdump.txt
gzip --best -k *.nes
