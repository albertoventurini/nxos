.386
;Fire effect for NXOS
Code	segment
	assume cs:Code

org 0h

main	proc
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

;	mov dx,64		;allocate memory
;	mov ah,00h
;	int 23h

	mov ah,03h
	mov dx,64
	int 2fh

;	xor di,di
;
;	mov ch,7dh
;	xor ax,ax
;	rep stosw		;free it
;	push es
;	pop ds

	mov cs:[BaseOfst],edi

	xor ax,ax
	mov es,ax
	mov ds,ax
	mov cx,32768

freemem1:
	mov es:[edi],ax
	add edi,2
	loop freemem1


	mov ax,0a000h
	mov es,ax

	xor eax,eax

l0:
	mov esi,cs:[BaseOfst]
	xor edi,edi
	mov cx,220
l1:
	push cx
	mov bx,320
	call random
	pop cx
l2:
	add ax,64320
;	mov esi,eax

	push esi
	add esi,eax
	mov al,255
	mov ds:[esi],al
	pop esi
	dec cx
	jnz l1

	xor esi,esi
fireup:				;the fire algorythm
	xor ax,ax
;	cwd
	xor dx,dx		;xor is faster...
	mov al,byte ptr ds:[esi-640]
	add dx,ax
	mov al,byte ptr ds:[esi-1]
	add dx,ax
	mov al,byte ptr ds:[esi+1]
	add dx,ax
	mov al,byte ptr ds:[esi+320]
	add dx,ax
	shr dx,2
	mov byte ptr ds:[esi-320],dl
	mov byte ptr ds:[esi-640],dl
	inc esi
	jnz fireup

	mov cx,((64000-960)/2)
f1:
	mov ax,word ptr ds:[esi]
	mov word ptr es:[di],ax
	add esi,2
	add di,2
	dec cx
	jnz f1

	mov ah,11h
	int 16h
	jz l0

	mov ah,00h
	int 16h

;	mov ah,01h
;	mov dx,64
;	push ds
;	pop es
;	int 23h

	mov ax,0003h
	int 10h

	mov ah,02h
	mov bl,0
	int 20h

main	endp

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
BaseOfst dd ?

code	ends

end
