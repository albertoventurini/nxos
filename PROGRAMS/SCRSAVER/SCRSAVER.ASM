;Screen saver per NXOS
;---------------------


org 0h

Main:
	call Randomize

Loop1:
	mov bx,79
	mov ax,11111111b
	call Random

	mov dl,al

	mov bx,24
	mov ax,111111b
	call Random

	mov dh,al

	mov ah,03h
	int 20h

	mov bx,si
	shl bx,8

	mov ah,02h
	int 10h

	mov bx,255
	mov ax,00ffh
	call Random

	push ax
	mov bx,15
	mov ax,11111b
	call Random

	mov bl,al
	pop ax
	mov ah,00h
	int 24h

	mov ah,01h
	int 25h
	jz Loop1

	mov ah,00h
	int 25h

	mov ah,02h
	mov bl,0
	int 20h

;------------------------------------------------------------------------------

randomize:
	push dx
	mov dx,40h
	in ax,dx
	mov [cont],ax
	pop dx
	ret

;------------------------------------------------------------------------------

random:
;input bx=limitation
;      ax=bit limitation
;output ax=random num
;(uses ax bx cx)
	push ax
	mov ax,[cont]
	rol ax,3
	sub ax,7
	xor ax,2
	ror ax,1
	mov cx,[a1]
	add ax,cx
	inc cx
	mov [a1],cx
	mov cx,[a2]
	sub ax,cx
	sub cx,2
	mov [a2],cx
	mov [cont],ax
	pop cx
	and ax,cx
l1_r2:
	cmp ax,bx
	jbe fine_r2
	sub ax,bx
	jmp l1_r2
fine_r2:
	ret

;------------------------------------------------------------------------------

cont	dw ?
a1	dw ?
a2	dw ?