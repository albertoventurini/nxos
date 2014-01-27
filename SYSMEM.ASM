;Organizzazione della memoria di sistema

DATA	SEGMENT

Version			dw 0000h		;word, indica la versione del sistema
SystemId		db 30 dup (0)		;Š la stringa di identificazione del sistema (30 bytes)

;------------------------------------------------------------------------------
;FAT12

Fat12_MaxFiles equ 5

Fat12_FatSegment dw 0800h	;segmento in cui Š memorizzata la fat
Fat12_FatStart dw ?		;logical sector in cui Š presente la fat
Fat12_SectorsPerFat dw ?	;sectors per fat
Fat12_NumberOfFats db ?		;number of fats
Fat12_RootStart dw ?		;logical sector in cui inizia la root directory
Fat12_RootEntries dw ?	;number of root directory entries
Fat12_RootSectors dw ?	;length of root in sectors
Fat12_Chain	dw ?		;tiene traccia del settore successivo di un file
Fat12_CurrentDir dw ?	;Š il sector della directory corrente (inizializzato alla root) --> Š gi… stata compiuta l'operazione di sottrazione di 2 e aggiunta della "dataarea"
Fat12_CurrentDirSize dw ?	;grandezza della directory corrente in settori
Fat12_DirBuffer db 512 dup (?) ;buffer per memorizzare 1 settore di directory

;drive parameter
Fat12_Heads	dw ?
Fat12_Sectors dw ?
Fat12_Cylinders dw ?

;file data
Fat12_FileSector dw Fat12_MaxFiles dup (0)
Fat12_FileAttr db Fat12_MaxFiles dup (0)
Fat12_FileBytes dw Fat12_MaxFiles dup (0)
Fat12_FileSize dd Fat12_MaxFiles dup (0)

Fat12_DataArea dw ?	;inizio dell'area dati in logical sectors

;------------------------------------------------------------------------------

;Tabella per la gestione della memoria ( MaxKBytes Š specificato nel file
;"memmanag.asm" )

MaxKBytes equ 512

MemoryTable	db MaxKbytes dup (0)

;------------------------------------------------------------------------------

SystemError	db ?