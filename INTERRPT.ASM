;INT 20h --> Process management

InstallInterrupt:
	push ax
	push es
	xor ax,ax
	mov es,ax

;Installing Interrupt 20h
	mov ax,offset Int20h
	mov word ptr es:[20h*4],ax
	mov ax,cs
	mov word ptr es:[(20h*4)+2],ax

;Installing Interrupt 21h
	mov ax,offset Int21h
	mov word ptr es:[21h*4],ax
	mov ax,cs
	mov word ptr es:[(21h*4)+2],ax

;Installing Interrupt 22h
	mov ax,offset Int22h
	mov word ptr es:[22h*4],ax
	mov ax,cs
	mov word ptr es:[(22h*4+2)],ax

;Installing Interrupt 23h
	mov ax,offset Int23h
	mov word ptr es:[23h*4],ax
	mov ax,cs
	mov word ptr es:[(23h*4+2)],ax

	pop es
	pop ax

	ret

;------------------------------------------------------------------------------

Int20h:
	cmp ah,00h
	je Int20h_00h
	cmp ah,01h
	je Int20h_01h
	cmp ah,02h
	je Int20h_02h
	cmp ah,03h
	je Int20h_03h
	cmp ah,04h
	je Int20h_04h
	cmp ah,05h
	je Int20h_05h
	cmp ah,06h
	je Int20h_06h
	cmp ah,07h
	je Int20h_07h
	cmp ah,08h
	je Int20h_08h
	
	iret

Int20h_00h:
	call LoadProgram
	retf 2
Int20h_01h:
	call RunProcess
	iret
int20h_02h:
	call KillProcess
	iret
int20h_03h:
	call GetProcessInfo
	iret
int20h_04h:
	call SetVisibleProcess
	iret
int20h_05h:
	call GoToNextProcess
	iret
int20h_06h:
	call GetNextProcess
	iret
Int20h_07h:
	call LoadComProgram
	iret
Int20h_08h:
	call ExeLoader
	iret

;------------------------------------------------------------------------------

Int21h:
	cmp ah,00h
	je Int21h_00h
	cmp ah,01h
	je Int21h_01h
	cmp ah,02h
	je Int21h_02h
	iret

Int21h_00h:
	call EndSystem
	iret
Int21h_01h:
	call GetError
	iret
Int21h_02h:
	call SetError
	iret

;------------------------------------------------------------------------------

Int22h:
	cmp ah,00h
	je Int22h_00h
	cmp ah,01h
	je Int22h_01h
	cmp ah,02h
	je Int22h_02h
	cmp ah,03h
	je Int22h_03h
	cmp ah,04h
	je Int22h_04h
	cmp ah,05h
	je Int22h_05h

	iret

Int22h_00h:
	call Fat12_OpenFile
	sti
	retf 2
Int22h_01h:
	call Fat12_ReadFile
	iret
Int22h_02h:
	call Fat12_CloseFile
	iret
Int22h_03h:
	call Fat12_ChDir
	sti
	retf 2
Int22h_04h:
	call Fat12_GetFileSize
	iret
Int22h_05h:
	call Fat12_GetCurrentDirName
	iret

;------------------------------------------------------------------------------

Int23h:
	cmp ah,00h
	je Int23h_00h
	cmp ah,01h
	je Int23h_01h
	cmp ah,02h
	je Int23h_02h
	iret

Int23h_00h:
	call MemAlloc
	iret
Int23h_01h:
	call MemFree
	iret
Int23h_02h:
	call GetFreeMem
	iret

;------------------------------------------------------------------------------
