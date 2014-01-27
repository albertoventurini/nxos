;Driver della tastiera per NXOS
;------------------------------
;Written by: MaX and Alb‚ - 2001
;
;Questo driver sostituisce le routine dell'int 16h del bios.
;Controlla anche se particolari combinazioni di tasti sono state premute:
;
;CTRL+C o CTRL+Del --> Termina il processo visibile
;CTRL+N            --> Rende visibile il processo successivo

;Prossima funzione da implementare: GetString


org 0h

InstallDriver:
	cli
	xor ax,ax
	mov es,ax
	mov ax,offset Int25h
	mov word ptr es:[25h*4],ax
	mov ax,cs
	mov word ptr es:[(25h*4)+2],ax

	mov ax,word ptr es:[09h*4]
	mov word ptr cs:[OldInt09h],ax
	mov ax,word ptr es:[09h*4+2]
	mov word ptr cs:[OldInt09h+2],ax

	mov ax,offset Int09h
	mov word ptr es:[09h*4],ax
	mov ax,cs
	mov word ptr es:[09h*4+2],ax

	mov ah,02h
	mov bl,1
	int 20h

;==============================================================================

Int25h:
	cmp ah,00h
	je Int25h_00h
	cmp ah,01h
	je Int25h_01h
	cmp ah,02h
	je Int25h_02h
	cmp ah,03h
	je Int25h_03h
	cmp ah,04h
	je Int25h_04h
	cmp ah,05h
	je Int25h_05h
	cmp ah,06h
	je Int25h_06h
	cmp ah,07h
	je Int25h_07h
	iret
Int25h_00h:
	call GetKey
	iret
Int25h_01h:
	call TestKey
	retf 2	;Attenzione qui: uso "retf 2" invece di "iret", perchè iret 
		;ripristina lo stato dei
		;flags, mentre io voglio che il flag Z sia settato dalla
		;procedura "TestKey"
Int25h_02h:
	call GetStatus
	iret
Int25h_03h:
	call SetAutoRpt
	iret
Int25h_04h:
	call EndKeyboardDriver
	iret
Int25h_05h:
	call StoreKey
	iret
Int25h_06h:
	call GetKeyWithEcho
	iret
Int25h_07h:
	call GetStringWithEcho
	iret

;------------------------------------------------------------------------------

EndKeyboardDriver:
	xor ax,ax
	mov es,ax
	mov ax,word ptr cs:[OldInt09h]
	mov es:[09h*4],ax
	mov ax,word ptr cs:[OldInt09h+2]
	mov es:[09h*4+2],ax
	ret

;------------------------------------------------------------------------------

GetKey:
;prende il codice del tasto premuto dal buffer di tastiera e lo retituisce in AX
;Output: al=ascii-code ah=scan-code
	push cx
	push si

GetKey1:
	mov ah,03h
	int 20h
	cmp si,cx
	je GetKey2	;se il processo Š quello visibile, allora legge il tasto
	mov ah,05h	;altrimenti passa al processo successivo
	int 20h
	jmp GetKey1

GetKey2:
	Call TestKey
	jz GetKey1

	cli
	push ds
	mov ax,40h
	mov ds,ax
	mov si,word ptr ds:[HeadPtr] 	;carica in bx l'indirizzo del prossimo carattere
	mov ax,ds:[si] 		;preleva il carattere e lo mette in ax
	inc si
	inc si
	cmp si,ds:[82h]	;check for overflow
	jnz GetKey_End
	mov si,ds:[80h]	;ripristina il valore originale di HeadPtr

GetKey_End:
	mov word ptr ds:[HeadPtr],si
	pop ds

	pop si
	pop cx

	ret

;------------------------------------------------------------------------------

TestKey:
;verifica se e' disponibile un carattere nel buffer
; ZF=1 il carattere non e' disponibile
; ZF=0 il carattere e' disponibile
; se il car. e' disponibile allora al= ascii-code ah=scan-code 
; il carattere non viene rimosso dal buffer

	push ds
	push bx

TestKey1:
	mov ah,03h
	int 20h
	cmp si,cx
	je TestKey2
	mov ah,05h
	int 20h
	jmp TestKey1

TestKey2:
	mov ax, 40h
	mov ds, ax
	cli 			;regione critica
	mov bx, word ptr ds:[HeadPtr]
	mov ax, ds:[bx] 		;mette il carattere letto dal buffer in ax
	cmp bx, word ptr ds:[TailPtr] 	;ZF=1, se il buffer e' vuoto
	pop bx
	pop ds
	sti	;Bisogna ricordarsi di risettare l'interrupt flag, perchŠ
		;da TestKey non esco con un "iret" ma con "retf 2" (quindi
		;non viene risettato il valore originale dei flags)
	ret

;----------------------------------------------------------------------------------

GetStringWithEcho:
;Input: DS:[SI] --> buffer in cui memorizzare la stringa
;Output CX=numero di caratteri della stringa.
;La stringa finisce quando viene premuto CR (#13) (cioŠ Enter). Il carattere
;CR non viene memorizzato nel buffer
;I caratteri premuti vengono visualizzati sul video.

	push ax
	push si

	xor cx,cx

GetString1:
	call GetKey
	cmp al,13
	je GetString_End
	cmp al,8
	je GetString_DelPressed
	mov byte ptr ds:[si],al
	inc si
	inc cx
	mov ah,00h
	int 24h
	jmp GetString1

GetString_DelPressed:
	test cx,cx
	jz GetString1

	dec si
	dec cx
	mov al,' '
	mov byte ptr ds:[si],al

	mov ah,05h
	int 24h
	sub dl,1
	push dx
	mov ah,06h
	int 24h

	mov al,' '
	mov ah,00h
	int 24h

	pop dx
	mov ah,06h
	int 24h

	jmp GetString1

GetString_End:

	pop si
	pop ax

	ret

;------------------------------------------------------------------------------

GetKeyWithEcho:
;output AL=ascii code, AH=scan code

	call GetKey
	push ax
	mov ah,00h
	int 24h
	pop ax

	ret

;------------------------------------------------------------------------------

;patch dell'interrupt 09h
;Questo Š necessario per determinare la pressione di certe combinazioni di tasti
;(es CTRL+C --> termina il processo visibile...ecc.)

;Per maggiori informazioni, consultate il capitolo 20 del libro
;"The Art of Assembly Language".

Int09h:
	cli
	push ax
	push cx
	push ds


	mov ax,40h
	mov ds,ax
;	mov al,0adh
;	call SetCmd	;disabilita temporaneamente la tastiera

	cli
;	xor cx,cx

Int09h_Wait4Data:
;	in al,64h
;	test al,10b
;	loopnz Int09h_Wait4Data

	mov al,byte ptr ds:[17h]
	test al,100b
	jz OrigInt09h

	and al,11111011b
	mov byte ptr ds:[17h],al

	in al,60h
	cmp al,2eh	;guarda se Š stata premuta una C (per il CTRL+C)
	je Int09h_CtrlC
	cmp al,53h	;controlla se Š premuto Del
	je Int09h_CtrlC

	cmp al,31h	;controlla se Š premuto il tasto 'N'
	je Int09h_CtrlN

;	jmp OrigInt09h	;altrimenti salta all'interrupt originale

	mov al,20h
	out 20h,al

	pop ds
	pop cx
	pop ax

	iret


Int09h_CheckCtrlC:

;	mov al,byte ptr ds:[17h]
;	test al,100b		;controlla se Š premuto CTRL
;	jnz Int09h_CtrlC

;	jmp OrigInt09h

Int09h_CheckCtrlN:
;	mov al,byte ptr ds:[17h]
;	test al,100b
;	jnz Int09h_CtrlN

;	jmp OrigInt09h

Int09h_CtrlC:
;CTRL+C o CTRL+Del sono stati premuti
;	mov al,0aeh	;riabilita la tastiera
;	call SetCmd

	mov al,20h	;segnale di fine interrupt
	out 20h,al

	pop ds
	pop cx
	pop ax

	mov ah,02h	;termina il processo corrente
	mov bl,0
	int 20h

Int09h_CtrlN:
	mov ah,06h	;controlla qual'Š il processo successivo
	int 20h

	mov ah,02h	;setta visibile il processo successivo
	int 24h

;	mov al,0aeh	;riabilita la tastiera
;	call SetCmd

	mov al,20h	;segnale di fine interrupt
	out 20h,al

	pop ds
	pop cx
	pop ax
	iret

OrigInt09h:
;	mov al,0aeh	;riabilita la tastiera
;	call SetCmd

;	mov al,20h
;	out 20h,al

	pop ds
	pop cx
	pop ax

	jmp dword ptr cs:[OldInt09h]	;salta all'int 09h originale


;--------------------------------------

SetCmd:
;Questa procedura manda un comando al microcontroller della tastiera
;INPUT AL:comando da mandare
	push cx
	cli
	xor cx,cx

	push ax

SetCmd_Wait4Empty:
	in al,64h
	test al,10b
	loopnz SetCmd_Wait4Empty

	pop ax
	out 64h,al

	sti
	pop cx
	ret

;---------------------------------------------------------------------------------

;preleva lo stato dei tasti modificatori 
;NON TESTATO!!

GetStatus: 
	
	push ds
	mov ax, 40h
	mov ds, ax
	mov al, byte ptr ds:[KbdFlags1] 	;mette in al lo stato dei tasti modificatori
	pop ds

	ret

;----------------------------------------------

;setta il rapporto di autoripetizione
;bh=0, 1, 2, or 3 (delay in 1/4 sec before autorepeat starts) 
;and bl=0..1Fh (repeat rate, about 2:1 to 30:1 (chars:sec).

;BH=0 --> 250 ms
;BH=1 --> 500 ms
;BH=2 --> 750 ms
;Bh=3 --> 1 second

;BL=0 --> 30 rpts/sec
;BL=1 --> 26 rpts/sec
;...
;BL=1fh --> 2 rpts /sec

SetAutoRpt: 

	push ax	
	push cx
	push bx

	mov al, 0ADh 		;Disable kbd for now.
	call SetCmd
	and bh, 11b 		;Force into proper range.
	mov cl, 5
	shl bh, cl 		;Move to final position.
	and bl, 1Fh 		;Force into proper range.
	or bh, bl 		;8042 command data byte.
	mov al, 0F3h 		;8042 set repeat rate cmd.
	call SendCmd 		;Send the command to 8042.
	mov al, bh 		;Get parameter byte
	call SendCmd 		;Send parameter to the 8042.
	mov al, 0AEh 		;Reenable keyboard.
	call SetCmd
	mov al, 0F4h 		;Restart kbd scanning.
	call SendCmd

	pop bx
	pop cx
	pop ax

	ret

;----------------------------------------------


; memorizza il carattere in CX nel buffer
; CH=scan-code CL=ascii-code

;NON TESTATO!

StoreKey: 

	push ds
	push bx
	mov ax, 40h
	mov ds, ax
	cli 			;regione critica
	mov bx, word ptr ds:[TailPtr] 	;indirizzo di memorizzazione tasto 
	push bx 		;salva l'inidirizzo nello stack
	mov [bx], cx 		;memorizza 
	inc word PTR ds:[TailPtr] 	;incrementa il puntatore di coda
	cmp bx, word ptr ds:[HeadPtr] 	;sono stati sovrascritti dati?
	jne StoreOkay		;se non salta, se si continua
	pop word ptr cs:[TailPtr] 		;riprende il vecchio indirizzo e ignora
	sub sp, 2 		;sistema lo stack
StoreOkay: 
	add sp, 2 		;rimuove dati dallo stack
	pop bx
	pop ds

	ret

;-------------------------------------------------

; Spedisce un comando o un dato alla 
; keyboard data port (port 60h).

SendCmd:
	push ds
	push bx
	push cx
	mov cx, 40h
	mov ds, cx
	mov bx, ax 		;Salva il dato
	mov bh, 3 		
RetryLp: 
	cli
 	
; cancella il flag del registro KbdFlags4
; flags: Cancella errori , riconoscimento accettato, rispedisci flags

	and byte ptr ds:[KbdFlags4], 4fh

;aspetta finche' l'8042 processa il comando corrente

	xor cx, cx 
		
SendCmd_Wait4Empty: 
	in al, 64h 		;legge lo stato del registro
	test al, 10b 		;Input buffer pieno?
	loopnz SendCmd_Wait4Empty 		;aspetta finche' e' vuoto

				
; Ok spedisci i dato alla porta 60h
	
	mov al, bl	
	out 60h, al
	sti 			

; Wait for the arrival of an acknowledgement from the keyboard ISR:
	
	xor cx, cx 		
Wait4Ack: 
	test byte ptr ds:[KbdFlags4], 10 	;Acknowledge received bit.
	jnz GotAck
	loop Wait4Ack

	dec bh 			
	jne RetryLp

; If the operation failed after 3 retries, set the error bit and quit.

	or byte ptr ds:[KbdFlags4], 80h 	;Set error bit.

GotAck:
	pop cx
	pop bx
	pop ds
	ret

;--------------------------------------

; variabili BIOS 

KbdFlags1 equ 17h ; variabile che contiene lo stato dei tasti modificatori
KbdFlags2 equ 18h ; altra variabile  "      "   "    "     "    "
AltKpd 	  equ 19h
HeadPtr   equ 1ah ; puntatore alla testa del buffer
TailPtr   equ 1ch ; puntatore alla coda del buffer
Buffer    equ 1eh        ; buffer
EndBuf    equ 3eh
KbdFlags3 equ 96h ; miscellaneos keyboard flags
KbdFlags4 equ 97h ; "   "           "       "

;variabili driver

OldInt09h dd ?