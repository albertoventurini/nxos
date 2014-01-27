;NXOS
;Written by: Alberto Venturini (AlbÇ) - 2001
;Email address: -albe-@libero.it

;Modulo aggiuntivo di gestione della memoria
;Questo modulo cambia la modalitÖ del processore da 
;Real mode 16-bit a Real mode 32-bit.
;In questo modo si ha accesso a taaaanta memoria (64 Mbyte 
;al massimo...ma direi che sono pió che sufficienti!)
;e si ha comunque compatibilitÖ con la real mode 16-bit.

;Questo file va assemblato con tasm32.exe e linkato con un
;linker che supporti l'output in flat binary (".bin") (ad
;esempio elink.exe).

StartingOffset	equ 120000h	;Offset a partire dal quale ä disponibile
				;la memoria utente
TableOffset	equ 110000h	;Offset della tabella per l'allocazione

.386p

Code    Segment Para Public Use16
        Assume  CS:Code

org 0h

;------------------------------------------------------------------------------

Main:
;Installazione del driver
	cli
	xor ax,ax
	mov es,ax
	mov ax,offset Int2fh
	mov es:[2fh*4],ax
	mov ax,cs
	mov es:[2fh*4+2],ax

	call Real32Init

	mov ah,02h
	mov bl,1
	int 20h

;------------------------------------------------------------------------------

Int2fh:
	cmp ah,00h
	je Int2fh_00h
	cmp ah,01h
	je Int2fh_01h
	cmp ah,02h
	je Int2fh_02h
	cmp ah,03h
	je Int2fh_03h
	cmp ah,04h
	je Int2fh_04h
	cmp ah,05h
	je Int2fh_05h
	iret

Int2fh_00h:
	call Real32Init
	iret
Int2fh_01h:
	call Real32End
	iret
Int2fh_02h:
	call XMS_Avail
	iret
Int2fh_03h:
	call MemAlloc32
	iret
Int2fh_04h:
	call MemoryLeft
	iret
Int2fh_05h:
	call MemFree32
	iret

;------------------------------------------------------------------------------

Real32Init:
;Inizializza la Real Mode a 32 bit
;no Input, no Output
	pusha

	call Check_Safety	;giusto per sicurezza, anche se non dovrebbero
				;esserci errori.
	test ax,ax
	jnz Real32Init_Error

	call Enable_A20		;Inizializza la 32bit real mode
	call Pmode

	call XMS_Avail		;Calcola la memoria totale
	cmp ax,128
	jbe Real32Init_Error

	mov word ptr cs:[TotalMemory],ax ;Mettiamo la memoria totale in
					 ;questa variabile

Real32Init_PrepareTable:
	mov cx,ax	;In AX ho il numero totale di Kbytes presenti.
			;Inizializza il valore corrispondente a questi
			;Kbytes a zero.
	sub cx,64	;Toglie 64 (perchä ä primi 64 kbytes sono occupati
			;dalla tabella di allocazione della memoria).
	mov ax,0
	mov es,ax
	mov edi,TableOffset

Real32Init_Table2:
;Azzera tutte le posizioni nella tabella di allocazione della memoria
	mov es:[edi],al	;Nota: non funziona il "tradizionale" stosb...
	inc edi
	loop Real32Init_Table2

	popa

	ret

Real32Init_Error:

	call Disable_A20

	popa

	ret

;------------------------------------------------------------------------------

Real32End:
;Termina la Real Mode a 32 bit
	push ax
	call Disable_A20
	pop ax
	ret

;------------------------------------------------------------------------------

MemAlloc32:
;Input DX=numero di Kbytes da allocare
;Output EDI=offset a partire dal quale ä disponibile la memoria

	push ax
	push cx
	push dx
	push es

	xor ax,ax
	mov es,ax
	mov edi,TableOffset	;edi punta alla tabella di allocazione memoria

MemAlloc32_CheckSingle:
;Esegue questo ciclo finchä non trova un valore uguale a 0 (cioä un Kbyte
;libero).
	mov al,es:[edi]
	inc edi
	cmp di,cs:[TotalMemory]
	jae MemAlloc32_MemoryNotFound
	test al,al
	jnz MemAlloc32_CheckSingle

MemAlloc32_CheckTotal:
	mov cx,dx
	dec cx

MemAlloc32_CheckTotal2:
;Controlla se ci sono abbastanza Kbytes contigui liberi
	test cx,cx
	jz MemAlloc32_MemoryFound
	mov al,es:[edi]
	inc edi
	cmp di,cs:[TotalMemory]
	jae MemAlloc32_MemoryNotFound
	dec cx
	test al,al
	jz MemAlloc32_CheckTotal2

	jmp MemAlloc32_CheckSingle

MemAlloc32_MemoryFound:
	sub di,dx
	mov al,1

	push edi

MemAlloc32_MemoryFound2:
;Occupa la memoria!
	mov es:[edi],al
	inc edi
	dec dx
	jnz MemAlloc32_MemoryFound2

	pop edi

;Conversione di EDI: da indice nella tabella di allocazione a offset
	and edi,0000FFFFh

	shl edi,10	;converte il risultato in Kbytes

	add edi,StartingOffset

	pop es
	pop dx
	pop cx
	pop ax

	ret

MemAlloc32_MemoryNotFound:
	;[...]

	pop es
	pop dx
	pop cx
	pop ax

	ret

;------------------------------------------------------------------------------

MemoryLeft:
;questa procedura ritorna la memoria libera disponibile.
;CX=numero di Kbytes *contigui* liberi
;DX=numero di Kbytes *totali* liberi

	push ax
	push bx
	push es
	push edi

	mov edi,TableOffset
	xor ax,ax
	mov dx,ax
	mov bx,ax
	mov es,ax

MemoryLeft_1:
	mov al,es:[edi]
	inc edi
	cmp di,cs:[TotalMemory]
	je MemoryLeft_End
	test al,al
	jnz MemoryLeft_1

	inc dx
	mov cx,1

MemoryLeft_2:
	mov al,es:[edi]
	inc edi
	cmp di,cs:[TotalMemory]
	je MemoryLeft_End2
	test al,al
	jnz MemoryLeft_3
	inc cx
	inc dx
	jmp MemoryLeft_2

MemoryLeft_3:
	cmp cx,bx
	jbe MemoryLeft_1
	mov bx,cx
	jmp MemoryLeft_1

MemoryLeft_End2:
	cmp cx,bx
	jbe MemoryLeft_End
	mov bx,cx

MemoryLeft_End:
	pop edi
	pop es
	pop bx
	pop ax

	ret

;------------------------------------------------------------------------------

MemFree32:
;input EDI=offset a partire dal quale va liberata la memoria
;DX=numero di Kbytes da liberare

	push ax
	push dx
	push es
	push edi

	sub edi,StartingOffset
	shr edi,10

	add edi,TableOffset

	xor ax,ax
	mov es,ax

MemFree32_1:
	mov es:[edi],al
	inc edi
	dec dx
	jnz MemFree32_1

	pop edi
	pop es
	pop dx
	pop ax

	ret

;------------------------------------------------------------------------------

;Il codice sotto l'ho preso da un file di Alexei A. Frounze
;Il file originale si chiama "4gb.zip" ed ä scaricabile dal
;sito dell'autore: http://www.chat.ru/~alexfru

;--------------------------- A20 line switching ----------------------------

Enable_A20:
        Mov     AL, 0D1h
        Out     64h, AL
        Mov     AL, 0DFh
        Out     60h, AL
        Ret

Disable_A20:
        Mov     AL, 0D1h
        Out     64h, AL
        Mov     AL, 0DDh
        Out     60h, AL
        Ret

;----------- Checking processor mode and looking for Himem.sys -------------

Check_Safety:
        SMSW    CS:XXX
        Mov     AX, CS:XXX
        And     AX, 1
        JNZ     @@CSQ           ; 1 - Processor is in Protected Mode
@@CSQ:
        Ret
XXX     DW      ?

;------------------------- Getting XMS ammount -----------------------------

Read_CMOS:
        Out     70h, AL   ; CMOS address should be stored in the AL register
        Jmp     @@RCW     ; Little delay
@@RCW:
        In      AL, 71h   ; AL = value
        Ret


XMS_Avail:
;Output AX=memoria disponibile (con un massimo di circa 64Mb, 
;perchä ä una word...)
;Questa funzione restituisce la memoria XMS disponibile.

        Mov     AL, 31h   ; 31h = hi byte address
        Call    Read_CMOS
        Mov     AH, AL
        Mov     AL, 30h   ; 30h = low byte address
        Call    Read_CMOS ; AX = XMS installed above 1MB (in Kilobytes)
	sub ax,128 ;toglie 128 perchä la memoria disponibile inizia da 120000h
	ret

;-------- Protected mode intialization and creation of 4GB segment ---------

PMode:
        Xor     EAX, EAX
        Mov     AX, CS
        Shl     EAX, 4
        LEA     EDX, GDT
        Add     EAX, EDX
        Mov     DWord Ptr CS:GDTR+2, EAX; Fill in GDTR with physical address
                                        ; of Global Descriptor Table
        Push    DS
        CLI
        LGDT    FWord Ptr CS:GDTR       ; Load Global Descriptor Table
        Mov     EAX, 1
        Mov     CR0, EAX                ; Set Protected Mode
        Mov     AX, 8
        Mov     DS, AX
        Mov     ES, AX
        Mov     FS, AX
        Mov     GS, AX                  ; All segment registers are loaded
                                        ; with 4GB segment's selector
        Xor     EAX, EAX
        Mov     CR0, EAX                ; Set Real Mode
        STI
        Pop     DS

;----------------------------------------------------------;
; Now you can access all the memory by putting zero to a   ;
; segment register and 32bit physical address to an index  ;
; register.                                                ;
;                     -= Simple example =-                 ;
; Xor AX, AX                                               ;
; Mov ES, AX                  ; zero the ES register       ;
; Mov EDI, 1024*1024+65536    ; 1st byte we can use freely ;
; Mov BL, Byte Ptr ES:[EDI]   ; read byte                  ;
; Mov DWord Ptr ES:[EDI], EDX ; write dword                ;
;----------------------------------------------------------;

        Ret

;------------------------------------------------------------------------------

GDT     DQ      0, 8F92000000FFFFh      ; "0" & "4GB" Descriptors
GDTR    DW      16, 0, 0

TotalMemory dw ?
Errormsg db 'An error occurred while switching to 32-bit real mode',13,10,0

Code    EndS

End
