org 0h

main:
;	mov ax,0003h
;	int 10h

main2:
	mov si,offset msg1
	mov ah,01h
	mov bl,7
	int 24h

	mov si,offset msg2
	mov ah,01h
	mov bl,7
	int 24h

	mov ah,03h
	int 20h

	mov dx,si
	mov ah,03h
	int 24h

	mov si,offset msg3
	mov ah,01h
	mov bl,7
	int 24h

	mov ah,03h
	int 20h

	mov dx,cx
	mov ah,03h
	int 24h

	mov si,offset msg4
	mov ah,01h
	mov bl,7
	int 24h

	mov ah,02h
	int 2fh
	mov dx,ax
	mov ah,03h
	int 24h

	mov si,offset msg5
	mov ah,01h
	mov bl,7
	int 24h

	mov ah,02h
	int 23h
	mov dx,cx
	mov ah,03h
	mov bl,7
	int 24h

	mov si,offset msg6
	mov ah,01h
	mov bl,7
	int 24h

	mov dx,40
	mov ah,00h
	int 23h

	mov si,offset msg7
	mov ah,01
	mov bl,7
	int 24h

	mov dx,40
	mov ah,01h
	int 23h

	mov si,offset msg5
	mov ah,01h
	mov bl,7
	int 24h

	mov ah,02h
	int 23h
	mov dx,cx
	mov ah,03h
	mov bl,7
	int 24h

	mov si,offset msg8
	mov ah,01h
	mov bl,7
	int 24h

	mov ah,03h
	xor bx,bx
	int 25h

	mov si,offset msg9
	mov ah,01h
	mov bl,7
	int 24h

	mov si,offset filename
	mov ah,00h
	int 22h

	push si
	mov si,offset msg10
	mov ah,01h
	int 24h
	pop si

	mov ah,04h
	int 22h

	mov dx,ax
	mov ah,03h
	int 24h

	mov ah,02h
	int 22h

fine:
	mov ah,00h
	int 25h

	mov ah,02h
	mov bl,0
	int 20h

msg1	db 'Testing the system:',13,10,0
msg2	db 13,10,'Process number ... ',0
msg3	db 13,10,'Visible process ... ',0
msg4	db 13,10,'Total extended memory: ',0
msg5	db 13,10,'Base memory available: ',0

msg6	db 13,10,'Allocating 40 Kbytes of memory...',0
msg7	db 13,10,'Releasing 40 Kbytes of memory...',0

msg8	db 13,10,'Reprogramming the keyboard...',0

msg9	db 13,10,'Opening a file (test.bin)...',0
msg10	db 13,10,'File size:',0

nextline db 13,10,0

Cont	db 0

filename db 'TEST.BIN',0