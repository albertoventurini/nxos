;NXOS
;Written by: Alberto Venturini (Alb‚) - 2001
;Email address: -albe-@libero.it

;Questo codice funziona ma Š abbastanza "bad coded" (vedi Fat12_FileSearch)...
;Appena ho tempo lo devo riscrivere.


;Procedure "pubbliche":
;
;1) Fat12_FatInit
;   (no input, no output)
;
;2) Fat12_OpenFile
;   Input: DS:SI punta al nome del file da aprire
;   Output: SI Š il file handler.
;
;3) Fat12_CloseFile
;   Input: SI file handler
;
;4) Fat12_ReadFile
;   Input DX: numero di bytes da leggere
;         SI: file handler
;         ES:DI buffer in cui memorizzare il file
;5) Fat12_ChDir
;   Input DS:SI punta al nome della directory




Fat12_MaxFiles equ 5

;------------------------------------------------------------------------------

Fat12_DriveParams:
;chiama l'int 13h per sapere i parametri del drive 00h (il primo floppy drive)
;memorizza il numero di heads, sectors e cylinders del drive.
;Input: no inputs. Output: no outputs.
;Modifica AX,CX,DX
	mov ah,08h
	xor dx,dx
	int 13h
	mov al,dh
	xor ah,ah
	inc ax
	mov cs:[Fat12_Heads],ax
	mov al,cl
	and ax,3fh
	mov cs:[Fat12_Sectors],ax
	mov al,ch
	mov ah,cl
	mov cl,6
	shr ah,cl
	inc ax
	mov cs:[Fat12_Cylinders],ax
	ret

;------------------------------------------------------------------------------

Fat12_FatInit:
;inizializza le variabili che serviranno per la lettura dei file con la FAT12
;Questa procedura Š da chiamare prima di eseguire qualsiasi operazione con i
;file.
	push ax
	push cx
	push dx
	push es

	call Fat12_DriveParams
	mov ax,0800h
	mov cs:[Fat12_FatSegment],ax

	push si
	xor si,si
	xor ax,ax
Fat12_FatInit_ClearFile:
	mov word ptr cs:[Fat12_FileSector+si],ax
	add si,2
	cmp si,(Fat12_MaxFiles*2)
	jb Fat12_FatInit_ClearFile
	pop si

	xor ax,ax
	mov es,ax
	mov ax,word ptr es:[7c00h+0eh]	;reserved sectors (logical sector in cui inizia la fat)
	mov cs:[Fat12_FatStart],ax
	mov ax,word ptr es:[7c00h+16h]	;sectors per fat
	mov cs:[Fat12_SectorsPerFat],ax
	push ax
	mov al,byte ptr es:[7c00h+10h]	;number of fats
	mov cs:[Fat12_NumberOfFats],al
	cbw
	mov cx,ax
	pop ax
	mul cx
	add ax,cs:[Fat12_FatStart]
	mov cs:[Fat12_RootStart],ax
	mov cs:[Fat12_CurrentDir],ax

	mov ax,word ptr es:[7c00h+11h]	;root directory entries
	mov cs:[Fat12_RootEntries],ax
	mov ax,cs:[Fat12_SectorsPerFat]
	xor cx,cx
	mov cl,cs:[Fat12_NumberOfFats]
	mul cx				;AX=total fat sectors
	mov bx,ax
	mov ax,cs:[Fat12_RootEntries]
	mov cl,4
	shr ax,cl
	mov cs:[Fat12_RootSectors],ax
	mov cs:[Fat12_CurrentDirSize],ax
	add ax,bx
	add ax,cs:[Fat12_FatStart]
	mov cs:[Fat12_DataArea],ax

	pop es
	pop dx
	pop cx
	pop ax

	ret

;------------------------------------------------------------------------------

Fat12_ReadSector:
;this translates the logical sector value in AX, in CHS value
;logical sector in DX:AX (or simply in AX); then read the sector in ES:BX
;input:
;DX:AX=logical sector
;ES:BX=buffer
;CL=number of sectors to read
;Modifica AX,BX,CX,DX,SI
	push bx
	push cx
	mov bx,ax
	mov ax,dx
	xor dx,dx
	div cs:[Fat12_Sectors]
	mov cx,ax
	mov ax,bx
	div cs:[Fat12_Sectors]
	inc dx
	xchg cx,dx
	div cs:[Fat12_Heads]
	mov ch,al
	ror ah,1
	ror ah,1
	or cl,ah
	mov dh,dl
	mov dl,00h
	pop si
	pop bx
	mov ax,si
	mov ah,02h
	int 13h
	ret

;------------------------------------------------------------------------------

Fat12_WriteSector:
;this translates the logical sector value in AX, in CHS value
;logical sector in DX:AX (or simply in AX); then writes the sector from ES:BX
;input:
;DX:AX=logical sector to write
;ES:BX=data buffer
;CL=number of sectors to write

;	push bx
;	push cx
;	mov bx,ax
;	mov ax,dx
;	xor dx,dx
;	div [Fat12_Sectors]
;	mov cx,ax
;	mov ax,bx
;	div [Fat12_sectors]
;	inc dx
;	xchg cx,dx
;	div [Fat12_Heads]
;	mov ch,al
;	ror ah,1
;	ror ah,1
;	or cl,ah
;	mov dh,dl
;	mov dl,00h
;	pop si
;	pop bx
;	mov ax,si
;	mov ah,03h
;	int 13h
;	ret

;------------------------------------------------------------------------------

Fat12_NextCluster:
;input AX=current cluster
;output AX=fat value for current cluster (next cluster or eof...etc)
;Modifica AX
	push dx
	push es
	push di
	push ax
	mov di,3
	mul di
	shr ax,1
	mov di,ax
	mov ax,cs:[Fat12_FatSegment]
	mov es,ax
	mov ax,word ptr es:[di]
	pop di
	and di,1
	test di,di
	jz nextcluster_even
	push cx
	mov cl,4
	shr ax,cl
	pop cx
	jmp nextcluster_done
nextcluster_even:
	and ax,0fffh
nextcluster_done:
	pop di
	pop es
	pop dx
	ret

;------------------------------------------------------------------------------

Fat12_FileSearch:
;this looks for a file in the current directory
;entry:
;DS:SI=pointer to file name
;output:carry set if file not found
;carry clear if found - ES:DI points to file entry
;If a bad sector is found, the carry is set and DI is set to 0ffffh
;Modifica AX,BX,CX,DX,DI,ES

;Questa Š una delle procedure pi— "critiche" di tutto il supporto Fat...
	push cs:[Fat12_RootSectors]
	push cs:[Fat12_CurrentDir]

;	push cs
;	pop es

	push si
	push ds

;	call Fat12_GetFileName

file_ini:
	xor dx,dx
	mov ax,cs:[Fat12_CurrentDir]		;DX:AX=directory starting sector
	mov bx,offset Fat12_DirBuffer	;ES:BX=buffer
	push bx
	mov cl,1			;legge 1 settore
	push si
	call Fat12_ReadSector
	pop si
	pop di				;ES:DI=buffer

	xor dx,dx			;DX=counter
filenext:
	mov cx,11			;ogni nome di file Š lungo 11 bytes

	push si
	push di

	rep cmpsb

	pop di
	pop si
	je filefound
	add di,32			;passa alla prossima entry
	add dx,32
	cmp dx,512
	jb filenext			;se DX>512 vuol dire che dobbiamo passare ad un altro settore
	mov ax,cs:[Fat12_CurrentDir]
	cmp cs:[Fat12_DataArea],ax
	ja rootdir
	add ax,2
	sub ax,cs:[Fat12_Dataarea]		;sistemazione del valore del settore
	call Fat12_nextcluster
	cmp ax,0ff7h			;controlla se siamo alla fine della directory
	ja filenotfound
	je filesearch_badsector
	sub ax,2
	add ax,cs:[Fat12_DataArea]
	mov cs:[Fat12_CurrentDir],ax
	jmp file_ini
rootdir:
	dec cs:[Fat12_RootSectors]
	jz filenotfound
	inc cs:[Fat12_CurrentDir]
	jmp file_ini
filenotfound:
	stc

;	mov bx,0000h	;setta l'errore 0000h
;	mov ah,01h
;	int 21h

	jmp filesearch_end
filesearch_badsector:
	stc

;	mov bx,0001h	;setta l'errore 0001h
;	mov ah01h
;	int 21h

	mov di,0ffffh
	jmp filesearch_end
filefound:
	clc
filesearch_end:
	pop ds
	pop si

	pop cs:[Fat12_CurrentDir]
	pop cs:[Fat12_RootSectors]
	ret

;------------------------------------------------------------------------------

Fat12_GetFileName:
;input DS:[SI] name of the file
;This routine translates the name "namefile.ext" into NAMEFILEEXT

	push ax
	push cx
	push di
	push es

	mov di,offset GetFileNameBuffer
	mov cx,9

GetFileName_StoreFileName:
	lodsb
	cmp al,96
	jbe GetFileName_UpCaseOk

	sub al,32
GetFileName_UpCaseOk:
	cmp al,'.'
	je GetFileName_StoreExtension
	dec cx
	jz GetFileName_StoreExtension
	stosb
	jmp GetFileName_StoreFileName

GetFileName_StoreExtension:
	test cx,cx
;	jz GetFileName_StoreExtension2
	jnz GetFileName_CompleteName
	lodsb
	cmp al,'.'
	jne GetFileName_NoExtension
	jmp GetFileName_StoreExtension


GetFileName_CompleteName:
	dec cx
	test cx,cx
	jz GetFileName_StoreExtension2
	mov al,' '
	rep stosb

GetFileName_StoreExtension2:
	mov cx,3
	rep movsb

GetFileName_NoExtension:
	mov si,offset GetFileNameBuffer

	push cs
	pop ds

	pop es
	pop di
	pop cx
	pop ax

	ret

GetFileNameBuffer db 12 dup (?)

;------------------------------------------------------------------------------

Fat12_ChDir:
;Cambia la directory corrente
;entry:
;DS:SI=pointer to directory name
;output:carry set if directory not found
;Modifica AX,BX,CX,DX,DI,ES

	push ax
	push bx
	push cx
	push dx
	push es
	push di

	push si
	push ds

	call Fat12_GetFileName
	push si
	add si,8
	mov al,' '
	mov cx,3
Fat12_ChDir_1:
	mov byte ptr ds:[si],al
	inc si
	loop Fat12_ChDir_1
	pop si

	call Fat12_FileSearch
	jc chdir_notfound
	mov al,byte ptr es:[di+0bh]	;legge gli attributi del file
	and al,00010000b
	cmp al,10h			;controlla se si tratta di una subdir
	stc
	jne chdir_notfound
	mov ax,word ptr es:[di+1ah]
	sub ax,2
	add ax,cs:[Fat12_DataArea]
	mov cs:[Fat12_CurrentDir],ax

	mov cx,8
	mov di,offset Fat12_DirName

ChDir_StoreName1:
	mov al,byte ptr ds:[si]
	cmp al,' '
	jne ChDir_StoreName2
	mov al,0
ChDir_StoreName2:
	mov byte ptr cs:[di],al
	loop ChDir_StoreName1

	clc

chdir_notfound:
	pop ds
	pop si

	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;------------------------------------------------------------------------------

Fat12_GetCurrentDirName:
;output ES:DI=pointer to directory name
	mov di,cs
	mov es,di
	mov di,offset Fat12_DirName
	ret


Fat12_DirName db '\',0,'         '	;initial directory name (root directory)

;------------------------------------------------------------------------------

Fat12_OpenFile:
;entry:
;DS:SI=pointer to file name
;output:carry set if file not found
;SI=file number (if file was found)
;inizializes [file_sector] to the first sector of the file

	push ax
	push bx
	push cx
	push dx
	push es
	push di

	push cs
	pop es
	push ds
	push si
	call Fat12_GetFileName
	call Fat12_FileSearch
	pop si
	pop ds
	jc open_file_error2

	mov cx,Fat12_MaxFiles+1
	xor si,si
open_file_1:
	mov ax,cs:[Fat12_FileSector+si]
	test ax,ax
	jz open_file_2
	dec cx
	jz open_file_error
	add si,2
	jmp open_file_1
open_file_2:
	mov cx,si
	mov ax,es:[di+1ah]
	sub ax,2
	add ax,cs:[Fat12_DataArea]
	mov cs:[Fat12_FileSector+si],ax
	xor ax,ax
	mov cs:[Fat12_FileBytes+si],ax
	mov ax,word ptr es:[di+1ch]
	push si
	add si,si
	mov word ptr cs:[Fat12_FileSize+si+2],ax
	mov ax,word ptr es:[di+1eh]
	mov word ptr cs:[Fat12_FileSize+si],ax

	pop si
	mov al,byte ptr es:[di+0bh]
	shr si,1
	mov byte ptr cs:[Fat12_FileAttr+si],al
	mov si,cx
	clc
	jmp open_file_error2
open_file_error:
	stc
open_file_error2:
;	pop si
;	pop ds

	pop di
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;------------------------------------------------------------------------------

Fat12_CloseFile:
;input SI:number of file to close
	push ax
	xor ax,ax
	mov cs:[Fat12_FileSector+si],ax
	pop ax
	ret

;------------------------------------------------------------------------------

Fat12_ReadFile:
;input DX=number of bytes to read
;SI=file number
;ES:DI=buffer for data

	push ax
	push bx
	push cx
	push dx
	push si
	push di

	test dx,dx
	jz readfile_end1
readfile_ini:
	mov bx,offset Fat12_DirBuffer
	push dx
	xor dx,dx
	mov ax,cs:[Fat12_FileSector+si]
	mov cl,1
	push si
	push es

	push cs
	pop es
	call Fat12_ReadSector
	pop es
	pop si
	mov cx,cs:[Fat12_FileBytes+si]
	add bx,cx
	mov ax,512
	sub ax,cx
	mov cx,ax
	pop dx
r1:
	mov al,byte ptr cs:[bx]
	mov byte ptr es:[di],al

	inc word ptr cs:[Fat12_FileBytes+si]
;	dec dx
;	jz readfile_end1
	push si
	add si,si
	dec word ptr cs:[Fat12_FileSize+si+2]
	jnz r2
	cmp word ptr cs:[Fat12_FileSize+si],0
	je readfile_eof
	dec word ptr cs:[Fat12_FileSize+si]
	mov ax,0ffffh
	mov word ptr cs:[Fat12_FileSize+si+2],ax
	jmp r2

readfile_end1:
	jmp readfile_end
r2:
	pop si
	dec dx
	jz readfile_end
	inc bx
	inc di
	loop r1
	xor ax,ax
	mov word ptr cs:[Fat12_FileBytes+si],ax
	mov ax,word ptr cs:[Fat12_FileSector+si]
	add ax,2
	sub ax,cs:[Fat12_DataArea]
	call Fat12_NextCluster
	cmp ax,0ff7h
	ja readfile_badcluster
;	je readfile_eof
	je readfile_end
	sub ax,2
	add ax,cs:[Fat12_DataArea]
	mov word ptr cs:[Fat12_FileSector+si],ax
	jmp readfile_ini
readfile_eof:
	pop si
readfile_badcluster:
readfile_end:

	pop di
	pop si
	pop dx
	pop cx
	pop bx
	pop ax

	ret

;------------------------------------------------------------------------------

Fat12_WriteFile:
;This procedure writes to a file.
;input:
;SI=number of file
;ES:DI=data buffer
;DX=number of bytes to write



;	ret

;------------------------------------------------------------------------------


Fat12_GetFileSize:
;Input SI=file handler
;Output AX=File size (per ora solo word...)

;Attenzione: questa procedura ritorna un valore corretto SOLO se viene chiamata
;subito dopo aver aperto il file.

	push si

	add si,si
	mov ax,word ptr cs:[Fat12_FileSize+si+2]
	pop si

	ret

;------------------------------------------------------------------------------

