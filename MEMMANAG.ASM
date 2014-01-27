;Memory management module

StartSector equ 2000h

;------------------------------------------------------------------------------

MemInit:
	push ax
	push cx
	push si
	xor ax,ax
	mov cx,MaxKBytes
	xor si,si
MemInit_1:
	mov byte ptr cs:[MemoryTable+si],al
	inc si
	loop MemInit_1
	pop si
	pop cx
	pop ax

	ret

;------------------------------------------------------------------------------

MemAlloc:
;input DX=# di kbytes che servono
;output ES=segmento a partire dal quale la memoria Š disponibile.

	test dx,dx		;Non si possono allocare 0 Kbyes!
	jz MemAlloc_End

	push si
	push cx
	push ax

	call GetFreeMem		;Guarda se i Kbytes richiesti sono disponibili
	cmp cx,dx
	jb MemAlloc_NotFound2

	xor si,si
	push dx

MemAlloc_1:
;Cerca un Kbytes libero nella "MemoryTable"
	mov al,cs:[MemoryTable+si]
	test al,al
	jnz MemAlloc_GoOn
	dec dx
	jz MemAlloc_Found
	inc si
	cmp si,MaxKbytes
	jne MemAlloc_1
	jmp MemAlloc_NotFound

MemAlloc_GoOn:
	pop dx
	push dx
	inc si
	cmp si,MaxKbytes
	jb MemAlloc_1

MemAlloc_NotFound:
	pop dx
MemAlloc_NotFound2:
	mov ax,0a000h
	mov es,ax

	pop ax
	pop cx
	pop si

	ret

MemAlloc_Found:
	pop dx
	sub si,dx	;Si riporta al primo valore libero
	inc si

	push si

	mov al,1
MemAlloc_2:
	mov byte ptr cs:[MemoryTable+si],al
	inc si
	dec dx
	jnz MemAlloc_2

	pop si

	mov cl,6	;Converte il valore ottenuto in un segmento
	shl si,cl
	add si,StartSector
	mov es,si

	pop ax
	pop cx
	pop si

MemAlloc_End:

	ret

;------------------------------------------------------------------------------


MemFree:
;input DX=# di kbytes da liberare
;      ES=segmento a partire dal quale la memoria deve essere liberata
;         (deve essere multiplo di 40h)


;Ora la procedura funziona correttamente...

	test dx,dx
	jz MemFree_End2

	push ax
	push cx
	push dx
	push si

	mov si,es
	sub si,StartSector
	mov cl,6
	shr si,cl


	mov al,0
MemFree_1:
	mov byte ptr cs:[MemoryTable+si],al
	inc si
	dec dx
	jnz MemFree_1

MemFree_End:
	pop si
	pop dx
	pop cx
	pop ax

MemFree_End2:
	ret

;------------------------------------------------------------------------------

GetFreeMem:
;input: no input
;output: CX=numero massimo di Kbytes contigui liberi che ha trovato

	push ax
	push dx
	push si

	xor si,si
	xor cx,cx
	xor dx,dx

GetFreeMem_Again1:
	mov al,byte ptr cs:[MemoryTable+si]
	test al,al
	jnz GetFreeMem_NotFree
	inc cx

GetFreeMem_Again2:
	inc si
	cmp si,MaxKBytes
	jb GetFreeMem_Again1

	cmp cx,dx
	ja GetFreeMem_Fine2

GetFreeMem_Fine:
	mov cx,dx
GetFreeMem_Fine2:
	pop si
	pop dx
	pop ax

	ret

GetFreeMem_NotFree:
	cmp cx,dx
	jbe GetFreeMem_NotFree2
	mov dx,cx

GetFreeMem_NotFree2:
	xor cx,cx
	jmp GetFreeMem_Again2

;------------------------------------------------------------------------------
