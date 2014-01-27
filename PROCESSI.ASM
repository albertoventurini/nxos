MaxProcess equ 7

;MULTITASKER

;Procedure "pubbliche":

;1) StartMultiTasking (no input, no output)
;2) LoadProgram
;   Input: CS:SI --> nome del file che contiene il programma
;   Output: ES:DI --> indirizzo a partire dal quale ä stato memorizzato il codice
;3) RunProcess (da chiamare subito dopo LoadProgram per iniziare l'esecuzione
;   del processo)
;4) KillProcess


;------------------------------------------------------------------------------

StartMultiTasking:
	mov word ptr cs:[CurrentProg],0
	mov al,1
	mov byte ptr cs:[ProcessList],al 

	pushf
	cli
	call InstallTimerInt
	popf

	ret

;------------------------------------------------------------------------------

EndMultiTasking:
	push ax
	push es

	xor ax,ax
	mov es,ax
	mov ax,word ptr cs:[oldint]
	mov es:[(1ch*4)],ax

	mov ax,word ptr cs:[oldint+2]
	mov es:[(1ch*4+2)],ax

	pop es
	pop ax

	ret

;------------------------------------------------------------------------------

GetProcessInfo:
;No input
;Output: SI --> [CurrentProg] (processo corrente)
;        CX --> [VisibleProcess]

	mov si,word ptr cs:[CurrentProg]
	mov cx,word ptr cs:[VisibleProcess]
	ret

;------------------------------------------------------------------------------

SetVisibleProcess:
;input SI --> numero del processo da rendere visibile
	push ax

	mov al,byte ptr cs:[ProcessList+si]
	test al,al
	jz SetVisibleProcess_End

	mov word ptr cs:[VisibleProcess],si

SetVisibleProcess_End:
	pop ax
	ret

;------------------------------------------------------------------------------

GetNextProcess:
;output SI --> processo attivo successivo al processo corrente
;esempio sono attivi i processi 0 e 1, ed ä visibile il processo 1.
;In questo caso, GetNextProcess restituirÖ 0.

	push ax

	mov si,word ptr cs:[CurrentProg]

GetNextProcess_ScanList:
	inc si
GetNextProcess_ScanList2:
	mov al,byte ptr cs:[ProcessList+si]
	cmp si,(MaxProcess)
	je GetNextProcess_RestartScan
	test al,al
	jz GetNextProcess_ScanList

	pop ax

	ret

GetNextProcess_RestartScan:
	xor si,si
	jmp GetNextProcess_ScanList2

;------------------------------------------------------------------------------

LoadProgram:
;input DS:SI nome del file che contiene il programma
;output ES:DI indirizzo a partire dal quale ä stato memorizzato il codice
;	DX=Memoria allocata per il programma (in Kbytes)

	cli

	push ax

	call Fat12_OpenFile		;apre il file
	jc LoadProgram_Error
	call Fat12_GetFileSize		;ottiene la grandezza del file

	mov dx,ax

	mov cl,10
	shr dx,cl	;DX=DX/1024
	add dx,2	;Calcola la memoria da allocare (alloca 2kb in pió
			;necessari per lo stack)

	push dx

	call MemAlloc

	mov dx,ax
	xor di,di
	push es
	push di

;	xor di,di
	call Fat12_ReadFile		;legge il file
	call Fat12_CloseFile		;chiude il file

	pop di
	pop es
	pop dx

	pop ax
	sti

	ret

LoadProgram_Error:
	sti
	xor dx,dx
	pop ax
	ret

;RealDS	dw 0

;------------------------------------------------------------------------------

LoadComProgram:
;input DS:SI nome del file
;      DS:BX parametri
;output ES:DI indirizzo a partire dal quale ä memorizzato il codice
;	(per default DI=100h)
;	DX memoria allocata per il programma (in kbytes)

;Da aggiungere: costruzione del PSP (program segment prefix)

	cli

	push ax

	call Fat12_OpenFile
	jc LoadComProgram_Error

	mov dx,64	;per avere completa compatibilitÖ con il formato "com"
			;del dos, alloco 64 Kb di memoria

	push dx

	call MemAlloc	;alloca 64 kb di memoria

	call Fat12_GetFileSize
	mov dx,ax

	push bx
	push cx

	mov di,80h
	mov cx,80h

LoadComProgram_LoadParameters:
	mov al,byte ptr ds:[bx]
	mov byte ptr es:[di],al
	inc bx
	inc di
	loop LoadComProgram_LoadParameters

	pop cx
	pop bx


	mov di,100h	;offset iniziale 100h
	push es
	push di

	call Fat12_ReadFile	;memorizza il file a partire da ES:[100h]
	call Fat12_CloseFile

	pop di
	pop es
	pop dx

	pop ax

	ret

LoadComProgram_Error:
	xor dx,dx
	pop ax
	ret

;------------------------------------------------------------------------------

RunProcess:
;Fa in modo che un processo, giÖ caricato in memoria, sia eseguito.
;input ES:DI=segment:offset di partenza del processo.
;	DX=memoria allocata per il programma
;	BL=0 --> rende visibile il processo (normale)
;	BL=1 --> non rende visibile il processo
;La procedura setta P_Ds, P_Es, P_Ss del processo uguali a ES.
;P_Sp del processo = 0fffah
;Gli altri registri = 0
;Flags = indefiniti
;
;Carica nello stack del processo i flags, il segmento e l'offset del processo
;cosç l'interrupt del timer sa dove tornare con IRET.
;Rende visibile il processo caricato.

;Questa procedura ä un po' incasinata...

	push ax
	push si
	pushf

	pushf
	cli

;Cerca un posto libero nella "ProcessList"
	mov si,0ffffh
RunProcess_Loop1:
	inc si
	cmp si,(MaxProcess)
	jae RunProcess_Error1
	mov al,byte ptr cs:[ProcessList+si]
	test al,al
	jnz RunProcess_Loop1

;Ora in SI ho il numero del primo processo libero...

	mov al,1
	mov byte ptr cs:[ProcessList+si],al	;"occupa" il posto nella ProcessList

	test bl,bl
	jnz RunProcess_DontSetVisible	;Nuova opzione: se BL=1 allora il
					;processo non viene reso visibile
					;(utile per processi come i driver)

	mov ah,02h	;rende visibile il processo	
	int 24h

RunProcess_DontSetVisible:
	add si,si

	jmp RunProcess_2

RunProcess_Error1:
	popf
	popf
	pop si
	pop ax
	ret

RunProcess_2:

	push si
	mov ax,es

	add si,si		;Salva in ProcessMemory la memoria occupata
	mov word ptr cs:[ProcessMemory+si],ax	;dal programma

	mov ax,dx

	mov word ptr cs:[ProcessMemory+si+2],ax
	pop si

	push cx
	mov cl,10
	shl dx,cl	;DX=DX*1024
	sub dx,6	;Calcola la posizione iniziale di SP
	pop cx

	mov word ptr cs:[P_Sp+si],dx	;Salva SP iniziale (importante!)

	mov ax,es
	mov word ptr cs:[P_Ss+si],ax	;setta i valori dei segment registers
	mov word ptr cs:[P_Ds+si],ax
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

	push si
	mov si,dx

	mov word ptr es:[si+4],ax
	mov ax,es
	mov word ptr es:[si+2],ax
	mov word ptr es:[si],di

	pop si

	popf
	pop si
	pop ax

	ret

;------------------------------------------------------------------------------

KillProcess:
;Elimina dalla lista di esecuzione il processo puntato da cs:[CurrentProg]
;Input BL = 0 --> Libera la memoria occupata dal programma
;      BL = 1 --> Non libera la memoria (Terminate and stay resident)
	
	cli		;meglio disabilitare gli interrupt...

	mov ah,04h	;"ClearScreen": cancella lo schermo del processo
	int 24h		;da terminare

	mov si,word ptr cs:[CurrentProg]

	mov al,0
	mov byte ptr cs:[ProcessList+si],al

	cmp si,word ptr cs:[VisibleProcess]
	jne KillProcess_2 ;se il processo non ä visibile, lo termina
			  ;direttamente

;se invece il processo ä visibile, allora ne deve cercare un altro
;da rendere visibile

	push si

KillProcess_NextVisibleProcess:
;cerca il prossimo processo visibile
	dec si
	cmp si,0ffffh
	je KillProcess_1
	mov al,byte ptr cs:[ProcessList+si]
	test al,al
	jz KillProcess_NextVisibleProcess

	mov ah,02h
	int 24h		;Attenzione, il driver video dev'essere presente!

	pop si

;controlla se c'ä un solo processo disponibile: in questo caso, infatti,
;non viene terminato. Se viene terminato l'ultimo processo disponibile,
;il sistema va in crash...

	jmp KillProcess_2

KillProcess_1:
	mov si,(MaxProcess)
	jmp KillProcess_NextVisibleProcess


KillProcess_2:
;controlla se BL=0...se non ä zero, allora la memoria del processo
;non viene liberata (Terminate and Stay Resident).
	test bl,bl
	jnz KillProcess_3

	add si,si	;SI=SI*4
	add si,si

	mov ax,word ptr cs:[ProcessMemory+si]
	mov es,ax
	mov dx,word ptr cs:[ProcessMemory+si+2]

	call MemFree		;libera la memoria occupata dal programma

KillProcess_3:
	sti

KillProcess_End:
	jmp KillProcess_End	;jmp infinito finchä non si verifica un
				;timer interrupt (che toglie definitivamente
				;l'esecuzione al processo).

;------------------------------------------------------------------------------

InstallTimerInt:
	push ax
	push es
	push di
	xor ax,ax
	mov es,ax
	mov di,(1ch*4)
	mov ax,word ptr es:[di]
	mov word ptr cs:[oldint],ax
	mov ax,offset TimerInt
	mov word ptr es:[di],ax

	add di,2
	mov ax,word ptr es:[di]
	mov word ptr cs:[oldint+2],ax
	mov ax,cs
	mov word ptr es:[di],ax
	pop di
	pop es
	pop ax
	ret

;------------------------------------------------------------------------------

TimerInt:

;salva tutti i registri tranne CS e IP, perchä tanto CS e IP sono giÖ
;salvati nello stack del programma chiamante.

	mov word ptr cs:[temp_si],si
	mov si,word ptr cs:[currentprog]
	add si,si

	mov word ptr cs:[p_ax+si],ax
	mov word ptr cs:[p_bx+si],bx
	mov word ptr cs:[p_cx+si],cx
	mov word ptr cs:[p_dx+si],dx
	mov word ptr cs:[p_di+si],di
	mov ax,ds
	mov word ptr cs:[p_ds+si],ax
	mov ax,es
	mov word ptr cs:[p_es+si],ax
	mov ax,ss
	mov word ptr cs:[p_ss+si],ax
	mov word ptr cs:[p_sp+si],sp
	mov word ptr cs:[p_bp+si],bp
	mov di,si
	mov ax,word ptr cs:[temp_si]
	mov word ptr cs:[p_si+di],ax


;Ora cerca nella ProcessList il prossimo processo da attivare
	shr si,1	;lavoro in byte
;	xor cx,cx
goon_1:
	inc si
goon_12:
;	inc cx
;	cmp cx,(MaxProcess+1)
;	je TimerInt_EndSystem
	mov al,byte ptr cs:[ProcessList+si]
	cmp si,(MaxProcess)
	jb TimerInt_TestAl

	xor si,si
	jmp goon_12

TimerInt_TestAl:
	test al,al
	jz goon_1


;Ora in SI ho il numero del processo da eseguire

goon_2:
	mov word ptr cs:[CurrentProg],si

	add si,si	;lavoro in word

	mov bx,word ptr cs:[p_bx+si]
	mov cx,word ptr cs:[p_cx+si]
	mov dx,word ptr cs:[p_dx+si]
	mov di,word ptr cs:[p_di+si]
	mov ax,word ptr cs:[p_ds+si]
	mov ds,ax
	mov ax,word ptr cs:[p_es+si]
	mov es,ax
	mov ax,word ptr cs:[p_ss+si]
	mov ss,ax
	mov sp,word ptr cs:[p_sp+si]
	mov bp,word ptr cs:[p_bp+si]
	mov ax,word ptr cs:[p_ax+si]
	mov si,word ptr cs:[p_si+si]

TimerInt_End:

	push ax
	mov al,20h
	out 20h,al
	pop ax

	iret

TimerInt_EndSystem:
	call EndSystem

temp_si dw 0

;---------------------------------

p_ax	dw MaxProcess dup 0
p_bx    dw MaxProcess dup 0
p_cx    dw MaxProcess dup 0
p_dx    dw MaxProcess dup 0
p_si    dw MaxProcess dup 0
p_di    dw MaxProcess dup 0
p_ds    dw MaxProcess dup 0
p_es    dw MaxProcess dup 0
p_ss    dw MaxProcess dup 0
p_sp    dw MaxProcess dup 0
p_bp    dw MaxProcess dup 0

CurrentProg dw 0	;indica il processo che ä attivo
VisibleProcess dw 0	;indica il processo che ä visibile

ProcessList db MaxProcess dup 0

ProcessMemory dd MaxProcess dup 0	;indica la memoria occupata da ogni
		;programma. La prima word indica il segmento (e si presuppone 
		;che l'offset sia 0), la seconda word indica la quantitÖ
		;di memoria occupata in kbytes.

;------------------------------------------------------------------------------

GoToNextProcess:
;Questa procedura serve al sistema operativo...ad esempio nel driver della
;tastiera: se un processo NON visibile ha chiesto un tasto e lo sta attendendo,
;finchä non ä visibile spreca solo risorse, quindi il driver della tastiera
;chiama questa funzione per passare al processo successivo.
	cli
	int 1ch
	ret

;------------------------------------------------------------------------------

oldint dd ?
longadr dd ?
