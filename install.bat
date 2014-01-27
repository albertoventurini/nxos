@echo off
cls
echo Questo programma installerà NXOS su un floppy disk.
echo Assicurarsi che sia inserito un dischetto VUOTO nel drive A:
pause
echo Copia del bootsector in corso...
PARTCOPY boot12.bin 0 3 -f0 0
PARTCOPY boot12.bin 3E 1C2 -f0 3E
echo Copia del Kernel in corso
copy kernel.bin a:\
echo Copia del driver video in corso
copy video.drv a:\
echo Copia del driver della tastiera in corso
copy keyboard.drv a:\
echo Copia del driver Real Mode 32-bit in corso
copy bigmem.drv a:\
echo Copia della shell in corso
copy shell.bin a:\
echo Installazione completata