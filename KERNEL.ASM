;NXOS kernel
;-----------
;Written by: Alberto Venturini (Alb‚) - 2000/2001
;Email address: -albe-@libero.it
;------------------------------------------------
;
;
;Sorry, but comments are in italian... :(

org 0h

InitSystem:

;Inizializzo i segmenti
	mov ax,1000h
	mov ss,ax
	mov sp,0fffeh
	mov ds,ax

	mov ax,0003h
	int 10h
	mov si,offset InitSystemMsg
	call WriteSimple

;Inizializzo gli "exception handlers"
	call InstallExceptionHandlers

;Inizializzo gli interrupt per le chiamate di sistema
	call InstallInterrupt

;Inizializzo la Fat
	mov si,offset InitFat
	call WriteSimple
	call Fat12_FatInit

;Inizializzo la gestione della memoria
	mov si,offset InitMem
	call WriteSimple
	call MemInit

;Inizializzo la gestione dei processi multitasking
	mov si,offset InitMt
	call WriteSimple
	call StartMultiTasking

	mov al,13
	mov ah,0eh
	int 10h
	mov al,10
	int 10h

;Installo il driver video
	mov si,offset InitVideoDrv
	call WriteSimple

	mov si,offset VideoDrv
	call LoadProgram
	jc KeyboardInstall
	mov bl,1
	call RunProcess

KeyboardInstall:
;Installo il driver della tastiera
	mov si,offset InitKeyboardDrv
	call WriteSimple

	mov si,offset KeyboardDrv
	call LoadProgram
	jc BigMemInstall
	mov bl,1
	call RunProcess

BigMemInstall:
;Installo il driver per la Real mode 32-bit
	mov si,offset InitBigMemDrv
	call WriteSimple

	mov si,offset BigMemDrv
	call LoadProgram
	jc ShellInstall
	mov bl,1
	call RunProcess

ShellInstall:
	mov si,offset ContinueMsg
	call WriteSimple

	mov ah,00h
	int 25h

; [..]

	mov si,offset InitShell
	call WriteSimple

;	mov ah,00h
;	int 25h

	mov si,offset Shell
	call LoadProgram
	jc ErrorNoShell
	call RunProcess

	mov si,1
	mov ah,02h
	int 24h

InitSystem_End:
	mov ah,02h
	mov bl,1
	int 20h

ErrorNoShell:
	mov si,offset ErrorShell
	call WriteSimple

	mov ah,00h
	int 25h

	jmp EndSystem

;------------------------------------------------------------------------------

EndSystem:
	call EndMultiTasking

	mov ah,01h	;Termina la Real Mode a 32 bit.
	int 2fh

	mov ah,04h
	int 25h		;Termina il driver della tastiera

	mov si,offset ShutDown

EndSystem_WriteMsg:
	call WriteSimple
	mov ah,00h
	int 16h

	cmp al,'R'
	je EndSystem_Reboot
	cmp al,'r'
	je EndSystem_Reboot
	cmp al,'S'
	je EndSystem_ShutDown
	cmp al,'s'
	je EndSystem_ShutDown

	jmp EndSystem_WriteMsg

EndSystem_Reboot:
	int 19h

EndSystem_ShutDown:
	mov ax,5300h
	xor bx, bx
	int 15h
	mov ax,5304h
	xor bx, bx
	int 15h
	mov ax,5301h
	xor bx, bx
	int 15h
	mov ax,5307h
	mov bx,1
	mov cx,3
	int 15h

;------------------------------------------------------------------------------

SetError:
;input AL=codice dell'errore
	mov cs:[SystemError],al
	ret

;------------------------------------------------------------------------------

GetError:
;output AL=codice dell'errore
	mov al,cs:[SystemError]
	ret

;------------------------------------------------------------------------------

WriteSimple:
;input CS:SI --> indirizzo della stringa
	push ax
	push bx
	push si

	mov ah,0eh
	mov bx,7
WriteSimple_1:
	mov al,byte ptr cs:[si]
	test al,al
	jz WriteSimple_End
	int 10h
	inc si
	jmp WriteSimple_1

WriteSimple_End:
	pop si
	pop bx
	pop ax

	ret

;------------------------------------------------------------------------------

include Fat12d.asm
include MemManag.asm
include Processi.asm
include Interrpt.asm
include Except.asm
include LoadExeC.asm

;------------------------------------------------------------------------------
;Kernel Data

;Messaggi
InitSystemMsg db 'NXOS version 0.3.3',13,10,0
InitFat db 'Initializing filesystem: 12-bit Fat...',13,10,0
InitMem db 'Initializing 16-bit memory management...',13,10,0
InitMt	db 'Initializing process manager (multitasker)...',13,10,0
InitVideoDrv db 'Loading video driver (video.drv)...',13,10,0
InitKeyboardDrv db 'Loading keyboard driver (keyboard.drv)...',13,10,0
InitBigMemDrv db 'Loading 32-bit real mode driver (bigmem.drv)...',13,10,0
InitShell db 'Loading shell (shell.bin)...',13,10,0
ErrorShell db 'Error - file shell.bin not found.',13,10,0

ContinueMsg db 'Press any key to continue...',13,10,0

ShutDown db 'Do you want to (R)eboot or (S)hutdown?',0

;Shell	db 'SHELL   BIN'

;VideoDrv db 'VIDEO   DRV'
;KeyboardDrv db 'KEYBOARDDRV'

;BigMemDrv db 'BIGMEM  DRV'

Shell	db 'SHELL.BIN'
VideoDrv db 'VIDEO.DRV'
KeyboardDrv db 'KEYBOARD.DRV'

BigMemDrv db 'BIGMEM.DRV'

;------------------------------------------------------------------------------

include Sysmem.asm