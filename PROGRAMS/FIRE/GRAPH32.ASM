.386

Code	segment
	assume cs:Code

Main	proc
	mov ah,03h
	mov dx,64
	int 2fh

	xor ax,ax
	mov es,ax

	mov ax,0401h
	mov cx,32768
	push edi

Main1:
	mov es:[edi],ax
	add edi,2
	loop Main1

	pop edi

	mov ax,0013h
	int 10h

	mov esi,0a0000h

	mov cx,32768

Main2:
	mov ax,es:[edi]
	mov es:[esi],ax
	add edi,2
	add esi,2
	loop Main2

	mov ah,00h
	int 25h

	mov ax,0003h
	int 10h

	mov ah,02h
	mov bl,0
	int 20h

Main	endp

Code	ends

end