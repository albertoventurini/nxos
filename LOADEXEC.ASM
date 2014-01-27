;LoadExe - Exe file loader for NXOS
;
;Written by Alberto Venturini (Alb‚) - 2001
;-albe-@libero.it
;
;http://nxos.cjb.net

;EXE Header

Sig equ 0	;Exe signature "MZ"
MLength equ 2	;File size mod 512
Pages equ 4	;Length in pages (512 bytes)
Relocs equ 6	;Number of relocation items in relocation table
HeadSize equ 8	;Header size in paragraphs (16 btyes)
MinAlloc equ 10	;Minimum memory needed in paragraphs
MaxAlloc equ 12	;Maximum memory desired in paragraphs
DispSs equ 14	;Starting stack
BaseSp equ 16	;
Checksum equ 18	;
BaseIp equ 20	;Starting IP
DispCs equ 22	;Starting CS
RelocOfs equ 24	;Offset of relocation table
Overlay equ 26	;


ExeLoader:
;Main procedure.
;Input DS:[SI] --> file name

	push ax
	push bx
	push cx
	push dx
	push di
	push es

;Apre il file

	call Fat12_OpenFile
	jc ExeLoader_End1

	mov word ptr cs:[EL_FileHandler],si

;Ottiene la dimensione del file

	call Fat12_GetFileSize
	mov word ptr cs:[EL_SizeInBytes+2],ax

;Alloca la memoria necessaria per contenere il file

	shr ax,10	;Converte in kbytes
	inc ax		;"Melium abundare quam deficere..." :))
	mov dx,ax
	mov word ptr cs:[EL_MemoryAllocated],ax
	call MemAlloc

;Legge l'intero file nella memoria allocata

	mov dx,word ptr cs:[EL_SizeInBytes+2]
	xor di,di
	call Fat12_ReadFile

;Chiude il file...tanto non mi serve +

	call Fat12_CloseFile

;Controlla se Š un EXE

	mov ax,word ptr es:[Sig]
	cmp ax,'ZM'
	jne ExeLoader_End

	jmp EL_GoOn1

ExeLoader_End1:
	jmp ExeLoader_End

EL_GoOn1:
;Alloca il resto della memoria...ecc. ecc.

	push es
	call EL_AllocateMemory
	pop es
	call BuildPsp
	call LoadRelocs

	mov dx,word ptr es:[HeadSize]
	
	mov ax,es
	add ax,dx
	add es:[DispSs],ax
	add es:[DispCs],ax

	mov bl,0
	call RunExeProcess

	jmp ExeLoader_End

ExeLoader_Error:
	mov si,offset EL_ErrorMsg
	call WriteSimple

ExeLoader_End:
	pop es
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;------------------------------------------------------------------------------

EL_AllocateMemory:
;Alloca il resto della memoria
	mov dx,word ptr es:[MinAlloc]
	shr dx,6 ;Convert it in Kbytes
	push dx
	call MemAlloc
	pop dx
	add word ptr cs:[EL_MemoryAllocated],dx
	ret

;------------------------------------------------------------------------------

BuildPsp:
;input ES --> segment where the program will be stored
;The PSP will start at ES:100h

	ret

;------------------------------------------------------------------------------

LoadRelocs:
	test word ptr es:[Relocs],-1
	jz LoadRelocs_End

	push ds
	push si

	mov dx,es
	add dx,word ptr es:[HeadSize]	;DX contiene il segmento a partire dal
					;quale Š memorizzato il codice
	mov di,word ptr es:[RelocOfs]	;DI=offset della relocation table
	mov cx,word ptr es:[Relocs]	;CX=numero di relocation items

LoadRelocs_Loop1:
	mov ax,word ptr es:[di+2]	;carica il segmento
	add ax,dx			;aggiunge il "base segment"
	mov ds,ax
	mov si,word ptr es:[di]		;SI=offset
	add word ptr ds:[si],dx
	add di,4
	loop LoadRelocs_Loop1

	pop si
	pop ds

LoadRelocs_End:
	ret

;------------------------------------------------------------------------------

RunExeProcess:
;	BL=0 --> rende visibile il processo (normale)
;	BL=1 --> non rende visibile il processo

;Questa procedura Š un po' incasinata...

	push ax
	push si
	pushf

	pushf
	cli

;Cerca un posto libero nella "ProcessList"
	mov si,0ffffh
RunExeProcess_Loop1:
	inc si
	cmp si,(MaxProcess)
	jae RunExeProcess_Error1
	mov al,byte ptr cs:[ProcessList+si]
	test al,al
	jnz RunExeProcess_Loop1

;Ora in SI ho il numero del primo processo libero...

	mov al,1
	mov byte ptr cs:[ProcessList+si],al	;"occupa" il posto nella ProcessList

	test bl,bl
	jnz RunExeProcess_DontSetVisible	;Nuova opzione: se BL=1 allora il
					;processo non viene reso visibile
					;(utile per processi come i driver)

	mov ah,02h	;rende visibile il processo	
	int 24h

RunExeProcess_DontSetVisible:
	add si,si

	jmp RunExeProcess_2

RunExeProcess_Error1:
	popf
	popf
	pop si
	pop ax
	ret

RunExeProcess_2:

	push si
	mov ax,es

	add si,si		;Salva in ProcessMemory la memoria occupata
	mov word ptr cs:[ProcessMemory+si],ax	;dal programma

	mov ax,word ptr cs:[EL_MemoryAllocated]
	mov word ptr cs:[ProcessMemory+si+2],ax
	pop si

	mov dx,word ptr es:[BaseSp]
	sub dx,6
	mov word ptr cs:[P_Sp+si],dx	;Salva SP iniziale (importante!)

	mov ax,word ptr es:[DispSs]
	mov word ptr cs:[P_Ss+si],ax	;setta i valori dei segment registers
	mov ax,es
	mov ax,word ptr es:[DispCs]	;sistema il valore di DS iniziale
	sub ax,10h
	mov word ptr cs:[P_Ds+si],ax
	mov ax,es
	mov word ptr cs:[P_Es+si],ax
	xor ax,ax
	mov word ptr cs:[P_Ax+si],ax	;setta a 0 gli altri registri
	mov word ptr cs:[P_Bx+si],ax
	mov word ptr cs:[P_Cx+si],ax
	mov word ptr cs:[P_Dx+si],ax
	mov word ptr cs:[P_Bp+si],ax
	mov word ptr cs:[P_Si+si],ax
	mov word ptr cs:[P_Di+si],ax

	pop ax				;salva nello stack del processo i flags,
	or ax,0000001000000000b	;abilita l'interrupt flag

	push ds
	push si
	mov si,word ptr es:[DispSs]
	mov ds,si	;prepara lo Stack Segment

	mov si,dx


	mov word ptr ds:[si+4],ax
	mov ax,word ptr es:[DispCs]
	mov word ptr ds:[si+2],ax
	mov ax,word ptr es:[BaseIp]
	mov word ptr ds:[si],ax

	pop si
	pop ds

	popf
	pop si
	pop ax

	ret

;------------------------------------------------------------------------------

;------------------------------------------------------------------------------

EL_FileHandler dw ?
EL_ErrorMsg db 13,10,'An error occurred while opening the EXE file.',13,10,0
EL_SizeInBytes dd ?
EL_MemoryAllocated dw ?

