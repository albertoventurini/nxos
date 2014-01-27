;Driver video per NXOS

MaxProcess equ 7

org 0h

InstallDriver:
;Questa procedura installa l'interrupt 24h che sar… usato dal driver video

	cli
	xor ax,ax
	mov es,ax
	mov ax,offset Int24h
	mov es:[24h*4],ax
	mov ax,cs
	mov es:[24h*4+2],ax

	mov ah,02h	;termina il processo
	mov bl,1	;non libera la memoria (perchŠ le procedure devono
			;essere sempre presenti in memoria)
	int 20h

;------------------------------------------------------------------------------

Int24h:
	cmp ah,00h
	je Int24h_00h
	cmp ah,01h
	je Int24h_01h
	cmp ah,02h
	je Int24h_02h
	cmp ah,03h
	je Int24h_03h
	cmp ah,04h
	je Int24h_04h
	cmp ah,05h
	je Int24h_05h
	cmp ah,06h
	je Int24h_06h
	cmp ah,07h
	je Int24h_07h
	iret

Int24h_00h:
	call WriteChar
	iret
Int24h_01h:
	call WriteString
	iret
Int24h_02h:
	call SetVisibleProcess
	iret
Int24h_03h:
	call WriteNumber
	iret
Int24h_04h:
	call ClearScreen
	iret
Int24h_05h:
	call GetCursorPos
	iret
Int24h_06h:
	call SetCursorPos
	iret
Int24h_07h:
	call GetChar
	iret

;------------------------------------------------------------------------------

WriteChar:
;input AL=carattere da scrivere
;      BL=attributi

;Da aggiungere: supporto per lo "scrolling" verticale

;Finalmente sostituita la procedura del bios con una mia procedura!

	push ax
	push bx
	push cx
	push dx
	push si

	mov ah,03h
	int 20h

;	mov dx,si
;	mov bh,dl

	cmp al,13
	je WriteChar_13
	cmp al,10
	je WriteChar_10
	test al,al
	jz WriteChar_End
	cmp al,9
	je WriteChar_09

	push ax
	push di
	push es

	call GetCursorPos

	mov di,dx
	shr di,8
	push ax
	mov ax,80
	push dx
	mul di
	pop dx
	xor dh,dh
	mov di,ax
	add di,dx
	add di,di

	mov ax,0b000h
	mov es,ax
	add di,8000h
	mov ax,si
	shl ax,12
	add di,ax
	pop ax
	mov ah,bl
	stosw

	pop es
	pop di
	pop ax


	jmp WriteChar_AggiornaCursore

WriteChar_13:
	call GetCursorPos

	mov dl,0
;	mov ah,02h
;	int 10h
	call SetCursorPos
	jmp WriteChar_End

WriteChar_10:
	call GetCursorPos

	cmp dh,24
	je WriteChar_ScrollUp

	inc dh
;	mov ah,02h
;	int 10h
	call SetCursorPos
	jmp WriteChar_End

WriteChar_09:
	call GetCursorPos
	add dl,9
	cmp dl,80
	jbe WriteChar_09_Ok

	sub dl,80
	inc dh

WriteChar_09_OK:
	call SetCursorPos
	jmp WriteChar_End

WriteChar_AggiornaCursore:
	call GetCursorPos

	cmp dl,79
	je WriteChar_NextLine
	inc dl
;	mov ah,02h
;	int 10h
	call SetCursorPos

WriteChar_End:
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	ret

WriteChar_NextLine:
	cmp dh,24
	je WriteChar_ScrollUp
	mov dl,0
	inc dh
;	mov ah,02h
;	int 10h
	call SetCursorPos
	jmp WriteChar_End

WriteChar_ScrollUp:
;int 10h funzione 06h:scroll up window
;Da sostituire con una mia funzione: questa funziona solo con le pagine attive
	xor cx,cx	;in CX c'Š il punto in alto a sinistra della finestra
	mov ah,06h
	mov al,1	;in AL c'Š il numero di righe da aggiungere
	mov bh,07h	;in BH ci sono gli attributi per la nuova riga
	mov dh,24
	mov dl,79
	int 10h
	jmp WriteChar_End

;------------------------------------------------------------------------------

GetChar:
;input DL=X, DH=Y
;output AH=attributi del carattere, AL=carattere letto

	push dx
	call GetCursorPos
	mov bx,dx
	pop dx
	call SetCursorPos

	push bx

	mov ah,03h
	int 20h
	mov bx,si
	mov bh,bl
	mov ah,08h
	int 10h

	pop dx
	call SetCursorPos

	ret

;------------------------------------------------------------------------------

WriteString:
;input DS:[SI] --> indirizzo della stringa
;      BL --> attributi dei caratteri
;Nota: la stringa finisce con uno 0 o con un '$'
	push ax
	push si

WriteString_Ini:
	mov al,[si]
	test al,al
	jz WriteString_EndString
	cmp al,'$'
	je WriteString_EndString

	call WriteChar
	inc si
	jmp WriteString_Ini

WriteString_EndString:
	pop si
	pop ax

	ret

;------------------------------------------------------------------------------

SetVisibleProcess:
;input SI --> numero del processo da rendere visibile

	cmp si,(MaxProcess)
	jae SetVisibleProcess_End

	cli

	push ax
	mov ax,si

	mov ah,05h
	int 10h

	mov ah,04h
	int 20h

	pop ax

SetVisibleProcess_End:
	ret

;------------------------------------------------------------------------------

WriteNumber:
;Scrive un numero decimale
;input DX=numero
	push ax
	push cx
	push dx

	push dx
	pop ax

	mov cx,0ffffh
	push cx
	mov cx,10
a1_shownum:
	xor dx,dx
	div cx
	or dl,30h
	push dx
	cmp ax,0
	jne a1_shownum
	pop ax
a2_shownum:
	mov bl,7
	call WriteChar
	pop ax
	cmp ax,0ffffh
	jne a2_shownum

	pop dx
	pop cx
	pop ax
	ret

;------------------------------------------------------------------------------

ClearScreen:
;Il nome dice tutto...
;Input SI=numero del processo il cui schermo verr… cancellato

	push ax
	push bx
	push cx
	push dx
	push es
	push di

	mov ah,03h
	int 20h

	mov ax,0b000h
	mov es,ax
	mov di,8000h

	mov ax,si
	shl ax,12
	add di,ax

	mov cx,2000
	mov ax,0720h
	rep stosw

	mov ax,si
	mov bh,al
	mov ah,02h
	xor dx,dx
	int 10h

	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax

	ret

;------------------------------------------------------------------------------

;==============================================================================

SetCursorPos2:
;Setta la posizione del cursore
;input: BL=X, BH=Y
;output: no output
	push ax
	push cx
	push dx
	mov al,bh
	cbw
;	mov cx,word ptr [Video_MaxX]
	mov cx,80
	mul cx				;AX=Y*80, BL=X,BH=Y
	xchg ax,bx			;AL=X,AH=Y, BX=Y*80
	cbw				;AX=X
	add bx,ax			;BX=X+(Y*80)
;	mov word ptr [Video_CursorPos],bx
	mov al,0eh
	mov ah,bh
	mov dx,3d4h
	out dx,ax
	mov al,0fh
	mov ah,bl
	out dx,ax
	pop dx
	pop cx
	pop ax
	ret

;==============================================================================

SetCursorPos:
;input DL=X, DH=Y
;Setta la posizione del cursore del processo chiamante

	push ax
	push bx
	push cx
	push si

	mov ah,03h
	int 20h
	mov bx,si
	mov bh,bl

	mov bl,0

	mov ah,02h
	int 10h

	pop si
	pop cx
	pop bx
	pop ax

	ret


;------------------------------------------------------------------------------

GetCursorPos:
;output DL=X position, DH=Y position
;Restituisce la posizione del cursore del processo chiamante

	push ax
	push bx
	push es

	push cx
	push si

	mov ah,03h
	int 20h
	mov bx,si
	add bx,bx
;	add si,si

	mov ax,40h
	mov es,ax

	mov dx,word ptr es:[50h+bx]

	pop si
	pop cx

	pop es
	pop bx
	pop ax

	ret


;==============================================================================


ProcessPage db 16 dup (0)
;ProcessCursor dw 16 dup (0)
Resolution	dw (80*50)
