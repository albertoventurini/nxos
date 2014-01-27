;Fire effect for NXOS
	org 0h

main:
	mov al,13h
	int 10h
	xor cx,cx
p1:
	mov ah,cl
	mov bh,cl
	shr bh,2
	call setpal
	inc cx
	cmp cx,11
	jne p1

p2:
	mov ah,cl
	mov bh,4
	call setpal
	inc cx
	cmp cx,21
	jne p2

p3:
	mov ah,cl
	mov bl,cl
	sub bl,20
	mov bh,4
	call setpal
	inc cx
	cmp cx,64
	jne p3

p4:
	mov ah,63
	mov bl,cl
	sub bl,20
	mov bh,2
	call setpal
	inc cx
	cmp cx,84
	jne p4

p5:
	mov bl,63
	xor bh,bh
	call setpal
	inc cx
	cmp cx,101
	jne p5

p6:
	mov bh,63
	call setpal
	inc cl
	test cl,cl
	jne p6

setseg:
;	mov ax,8000h		;some free memory...somewhere...
;	mov es,ax
;	mov cx,32000		;let's free this mem!

	mov dx,64		;allocate memory
	mov ah,00h
	int 23h

	xor di,di

	mov ch,7dh
	xor ax,ax
	rep stosw		;free it
	push es
	pop ds
	mov ax,0a000h
	mov es,ax

l0:	
	mov cx,220
l1:
	push cx
	mov bx,320
	call random
	pop cx
l2:
	add ax,64320
	mov si,ax
	mov al,255
	mov ds:[si],al
	dec cx
	jnz l1

	xor si,si
fireup:				;the fire algorythm
	xor ax,ax
;	cwd
	xor dx,dx		;xor is faster...
	mov al,byte ptr ds:[si-640]
	add dx,ax
	mov al,byte ptr ds:[si-1]
	add dx,ax
	mov al,byte ptr ds:[si+1]
	add dx,ax
	mov al,byte ptr ds:[si+320]
	add dx,ax
	shr dx,2
	mov byte ptr ds:[si-320],dl
	mov byte ptr ds:[si-640],dl
	inc si
	jnz fireup

	mov cx,((64000-960)/2)
f1:
	mov ax,word ptr ds:[si]
	mov word ptr es:[si],ax
	add si,2
	dec cx
	jnz f1

	mov ah,11h
	int 16h
	jz l0

	mov ah,00h
	int 16h

	mov ah,01h
	mov dx,64
	push ds
	pop es
	int 23h

	mov ax,0003h
	int 10h

	mov ah,02h
	mov bl,0
	int 20h

;------------------------------------------------------------------------------

setpal:
;input cl=color
;ah=red
;bl=green
;bh=blu
	mov dx,3c8h
	mov al,cl
	out dx,al
	inc dx
	mov al,ah
	out dx,al
	mov al,bl
	out dx,al
	mov al,bh
	out dx,al
	ret

;------------------------------------------------------------------------------

random:
;input BX=max num
	push es
	xor ax,ax
	mov es,ax
	mov ax,cs:cont
	mov cx,cs:a1
	mov dx,cs:a2
	add ax,dx
	add cx,es:[3083]
	sub dx,es:[3083]
	add dx,cx
	mov cs:cont,ax
	mov cs:a1,cx
	mov cs:a2,dx
	and ax,11111111111b
l1_r:
	cmp ax,bx
	jbe fine_r
	sub ax,bx
	jmp l1_r
fine_r:
	pop es
	ret

;------------------------------------------------------------------------------

a1	dw 10001
a2	dw 101
cont	dw 23923
