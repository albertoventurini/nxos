;NXOS
;--------
;Written by: Alberto Venturini (Alb‚) - 2001
;Email address: -albe-@libero.it
;
;NXOS exception handlers


;------------------------------------------------------------------------------

InstallExceptionHandlers:
	push ax
	push es

	xor ax,ax
	mov es,ax
	mov ax,offset Int00h
	mov word ptr es:[0000h],ax
	mov ax,cs
	mov word ptr es:[0000h+2],ax

	mov ax,offset Int06h
	mov word ptr es:[0006h*4],ax
	mov ax,cs
	mov word ptr es:[0006h*4+2],ax

	mov ax,offset Int07h
	mov word ptr es:[0007h*4],ax
	mov ax,cs
	mov word ptr es:[0007h*4+2],ax

	pop es
	pop ax

	ret

;-----------------------------------------------------------------------------

Int00h:
;L'interrupt 00h Š invocato quando si verifica una divisione per 0
;(quando il divisore di DIV o IDIV Š 0)
;Questa routine termina il processo che ha provocato l'errore.

	cli

	push cs
	pop ds

	mov si,offset Int00hMsg
	jmp TerminateProcess

;-----------------------------------------------------------------------------

Int06h:
;L'int 06h si verifica quando c'Š un'istruzione non valida.
;Termina il processo che ha provocato l'errore

	cli

	push cs
	pop ds

	mov si,offset Int06hMsg
	jmp TerminateProcess

;-----------------------------------------------------------------------------

Int07h:
;L'int 07h viene generato quando c'Š un'istruzione di un coprocessore
;che per• non Š presente.
;Termina il processo che ha provocato l'errore.

	cli

	push cs
	pop ds

	mov si,offset Int07hMsg
	jmp TerminateProcess

;-----------------------------------------------------------------------------

TerminateProcess:
;input SI --> offset del messaggio di errore da visualizzare

	push si

	mov ah,03h
	int 20h
	mov ah,04h
	int 24h

	mov si,offset GeneralErrorMsg
	mov ah,01h
	mov bl,7
	int 24h

	pop si
	int 24h

	mov si,offset TerminateProcessMsg
	int 24h

	mov ah,00h
	int 25h

	mov ah,02h
	mov bl,0
	int 20h

;-----------------------------------------------------------------------------

GeneralErrorMsg db 13,10,'Fatal error:',0
Int00hMsg	db ' division by zero (int 00h).',13,10,0
Int06hMsg	db ' invalid opcode (int 06h).',13,10,0
Int07hMsg	db ' processor extension not avaliable (int 07h).',13,10,0
TerminateProcessMsg db 'The process will be terminated.',13,10,0
