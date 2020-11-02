; ------------------------------------------------------------------
; MichalOS File Manager
; ------------------------------------------------------------------

	BITS 16
	%INCLUDE "redblockos.inc"
	ORG 100h

start:
	mov [.load_segment], gs

	call .draw_background

	mov byte [32767], 0
	
	call os_file_selector
	jc near .exit

	mov bx, ax
	mov cx, .screenstring
	mov ax, .root
	call os_string_join
	mov ax, bx
	
	push ax

	mov bx, cx
	
.commands:
	mov ax, .command_list			; Draw list of disk operations
	mov cx, .helpmsg
	call os_list_dialog

	jc near .clearstack				; User pressed Esc?

	cmp ax, 1						; Otherwise respond to choice
	je near .launch_file
	
	cmp ax, 2
	je near .file_operations
	
	cmp ax, 3
	je near .disk_info
	
.file_operations:
	mov ax, .file_cmd_list
	mov cx, .helpmsg
	call os_list_dialog
	
	jc .commands
	
	cmp ax, 1
	je near .create_file
	
	cmp ax, 2
	je near .delete_file
	
	cmp ax, 3
	je near .rename_file

	cmp ax, 4
	je near .copy_file
	
	cmp ax, 5
	je near .file_size

.clearstack:
	pop ax
	jmp start
	
.launch_file:
	mov al, 1
	mov [32767], al
	pop ax
	ret

.create_file:
	pop ax

	call .draw_background

	mov bx, .filename_msg			; Get a filename
	mov ax, .filename_input
	call os_input_dialog

	mov cx, 0				; Create an empty file
	mov bx, 4096
	mov ax, .filename_input
	call os_write_file

	jc near .writing_error

	jmp start

	

.delete_file:
	call .draw_background

	mov ax, .delete_confirm_msg		; Confirm delete operation
	mov bx, 0
	mov cx, 0
	mov dx, 1
	call os_dialog_box

	cmp ax, 0
	je .ok_to_delete

	pop ax
	jmp start

.ok_to_delete:
	pop ax
	call os_remove_file
	jc near .disk_error
	jmp start

.rename_file:
	call .draw_background

	pop ax
	
	mov si, ax				; And store it
	mov di, .filename_tmp1
	call os_string_copy

.retry_rename:
	call .draw_background

	mov bx, .filename_msg			; Get second filename
	mov ax, .filename_input
	call os_input_dialog

	mov si, ax				; Store it for later
	mov di, .filename_tmp2
	call os_string_copy

	mov ax, di				; Does the second filename already exist?
	call os_file_exists
	jnc .rename_fail			; Quit out if so

	mov ax, .filename_tmp1
	mov bx, .filename_tmp2

	call os_rename_file
	jc near .writing_error

	jmp start


.rename_fail:
	mov ax, .err_file_exists
	mov bx, 0
	mov cx, 0
	mov dx, 0
	call os_dialog_box
	jmp .retry_rename


.copy_file:
	call .draw_background

	pop ax
	
	mov si, ax				; And store it
	mov di, .filename_tmp1
	call os_string_copy

	call .draw_background

	mov bx, .filename_msg			; Get second filename
	mov ax, .filename_input
	call os_input_dialog

	mov si, ax
	mov di, .filename_tmp2
	call os_string_copy

	mov ax, .filename_tmp1
	mov bx, .filename_tmp2

	call os_get_file_size
	cmp ebx, 28672
	jl .no_copy_change
	
	mov word [.load_segment], gs
	mov word [.load_offset], 0000h
	
.no_copy_change:
	push es
	mov es, [.load_segment]
	mov cx, [.load_offset]
	call os_load_file
	
	mov cx, bx
	mov bx, [.load_offset]
	mov ax, .filename_tmp2
	call os_write_file
	pop es
	
	jc near .writing_error

	mov word [.load_segment], cs
	mov word [.load_offset], 1000h

	jmp start

.no_copy_file_selected:
	jmp start

.file_size:
	call .draw_background

	pop ax
	
	; Get the file size
	
	push ax
	mov si, .size_msg
	mov di, 16384
	call os_string_copy
	
	call os_get_file_size
	
	mov eax, ebx				; Move size into AX for conversion
	call os_32int_to_string
	mov bx, ax				; Size into second line of dialog box...
	mov ax, 16384
	call os_string_add
	
	mov bx, .bytes_msg
	call os_string_add
	
	; Get the file write date/time
	
	mov si, .time_msg
	mov di, 24576
	call os_string_copy
	
	pop ax
	call os_get_file_datetime

	push bx
	mov ax, cx		; Days
	and ax, 11111b
	
	call os_int_to_string
	mov bx, ax
	mov ax, 24576
	call os_string_add
	
	mov bx, .dateseparator
	mov ax, 24576
	call os_string_add

	mov ax, cx		; Months
	shr ax, 5
	and ax, 1111b
	
	call os_int_to_string
	mov bx, ax
	mov ax, 24576
	call os_string_add
	
	mov bx, .dateseparator
	mov ax, 24576
	call os_string_add
	
	mov ax, cx		; Years
	shr ax, 9
	add ax, 1980
	
	call os_int_to_string
	mov bx, ax
	mov ax, 24576
	call os_string_add

	mov bx, .whiteseparator
	call os_string_add
	
	pop cx
	
	mov ax, cx		; Hours
	shr ax, 11

	cmp ax, 10
	jge .no_hour_zero
	
	push ax
	mov bx, .zerofill
	mov ax, 24576
	call os_string_add
	pop ax
	
.no_hour_zero:
	call os_int_to_string
	mov bx, ax
	mov ax, 24576
	call os_string_add
	
	mov bx, .timeseparator
	mov ax, 24576
	call os_string_add
	
	mov ax, cx		; Minutes
	shr ax, 5
	and ax, 111111b
	
	cmp ax, 10
	jge .no_minute_zero
	
	push ax
	mov bx, .zerofill
	mov ax, 24576
	call os_string_add
	pop ax
	
.no_minute_zero:
	call os_int_to_string
	mov bx, ax
	mov ax, 24576
	call os_string_add
	
	mov bx, .timeseparator
	mov ax, 24576
	call os_string_add
		
	mov ax, cx		; Seconds
	and ax, 11111b
	shl ax, 1
	
	cmp ax, 10
	jge .no_second_zero
	
	push ax
	mov bx, .zerofill
	mov ax, 24576
	call os_string_add
	pop ax
	
.no_second_zero:
	call os_int_to_string
	mov bx, ax
	mov ax, 24576
	call os_string_add
	
	mov ax, 16384
	mov bx, 24576
	mov cx, 0
	mov dx, 0
	call os_dialog_box

	jmp start


.disk_info:
	pop ax
	
	mov cx, 1				; Load first disk sector into RAM
	mov dl, [0]
	mov dh, 0
	mov bx, .disk_buffer

	mov ah, 2
	mov al, 1
	stc
	int 13h					; BIOS load sector call

	jc .disk_error
	
	mov si, .disk_buffer + 2Bh		; Disk label starts here

	mov di, .tmp_string1
	mov cx, 11				; Copy 11 chars of it
	rep movsb

	mov byte [di], 0			; Zero-terminate it

	mov si, .disk_buffer + 36h		; Filesystem string starts here

	mov di, .tmp_string2
	mov cx, 8				; Copy 8 chars of it
	rep movsb

	mov byte [di], 0			; Zero-terminate it

	mov al, [0]
	
	cmp al, 00h
	je near .detect_floppy
	cmp al, 01h
	je near .detect_floppy
	cmp al, 80h
	je near .detect_hdd
	cmp al, 81h
	je near .detect_hdd
	cmp al, 0E0h
	je near .detect_cddvd
	
	mov bx, .disk_unknown
	
.detect_done:
	mov ax, .disk_type
	mov cx, .dstype_string_full
	call os_string_join

	mov ax, .label_string_text		; Add results to info strings
	mov bx, .tmp_string1
	mov cx, .label_string_full
	call os_string_join

	mov ax, .fstype_string_text
	mov bx, .tmp_string2
	mov cx, .fstype_string_full
	call os_string_join

	mov ax, .fstype_string_full
	call os_string_chomp
	
	mov ax, .fstype_string_full
	mov bx, .fstype_string_start
	call os_string_add
	
	call os_report_free_space
	shr ax, 1						; Divide by 2
	call os_int_to_string
	mov bx, ax
	mov ax, .fstype_string_full
	call os_string_add
	
	mov ax, .fstype_string_full
	mov bx, .fstype_string_ending
	call os_string_add
	
	call .draw_background

	mov ax, .label_string_full		; Show the info
	mov bx, .fstype_string_full
	mov cx, .dstype_string_full
	mov dx, 0
	call os_dialog_box

	jmp start


.writing_error:
	mov word [.load_segment], cs
	mov word [.load_offset], 1000h

	call .draw_background

	mov ax, 0
	mov bx, 0
	mov cx, 0
	mov dx, 0

	cmp byte [0086h], 0
	je .failure0
	cmp byte [0086h], 1
	je .failure1
	cmp byte [0086h], 2
	je .failure2
	cmp byte [0086h], 3
	je .failure3
	cmp byte [0086h], 4
	je .failure4

	mov ax, .error_msg
	mov bx, .error_msg2
	call os_dialog_box
	jmp start

.failure0:
	mov ax, .failure0msg
	call os_dialog_box
	jmp start
	
.failure1:
	mov ax, .failure1msg
	call os_dialog_box
	jmp start
	
.failure2:
	mov ax, .failure2msg
	call os_dialog_box
	jmp start
	
.failure3:
	mov ax, .failure3msg
	call os_dialog_box
	jmp start
	
.failure4:
	mov ax, .failure4msg
	call os_dialog_box
	jmp start

.exit:
	call os_clear_screen
	ret


.draw_background:
	mov ax, .title_msg
	mov bx, .footer_msg
	mov cx, 256
	call os_draw_background
	ret

.detect_floppy:
	mov bx, .disk_floppy
	jmp .detect_done
	
.detect_hdd:
	mov bx, .disk_hdd
	jmp .detect_done
	
.detect_cddvd:
	mov bx, .disk_cdrom
	jmp .detect_done
	
.file_error:
	mov ax, .fs_error
	mov bx, 0
	mov cx, 0
	mov dx, 0
	call os_dialog_box
	
	jmp start
	
.disk_error:
	mov ax, .dk_error
	mov bx, 0
	mov cx, 0
	mov dx, 0
	call os_dialog_box
	
	jmp start
	
	.command_list			db 'Run application,File operations,Show disk information', 0
	.file_cmd_list			db 'Create file,Delete file,Rename,Copy file,File information', 0

	.helpmsg				db '', 0
	
	.title_msg				db 'MichalOS File Manager', 0
	.footer_msg				db '', 0

	.label_string_text		db 'Disk name: ', 0
	.label_string_full		times 40 db 0
	
	.fstype_string_text		db 'File system: ', 0
	.fstype_string_start	db ' (', 0
	.fstype_string_ending	db ' kB free)', 0
	.fstype_string_full		times 40 db 0
	
	.delete_confirm_msg		db 'Are you sure?', 0

	.filename_msg			db 'Enter a new filename:', 0
	.filename_input			times 15 db 0
	.filename_tmp1			times 15 db 0
	.filename_tmp2			times 15 db 0

	.size_msg				db 'File size: ', 0
	.bytes_msg				db ' bytes', 0
	.time_msg				db 'Write date/time: ', 0
	.timeseparator			db ':', 0
	.root					db 'A:'
	.dateseparator			db '/', 0
	.whiteseparator			db ' ', 0
	.zerofill				db '0', 0
	
	.error_msg				db 'Error writing to the disk!', 0
	.error_msg2				db '(Disk is read-only/file already exists)?', 0

	.err_file_exists		db 'File with this name already exists!', 0

	.disk_type				db 'Disk type: ', 0
	.disk_floppy			db 'floppy disk', 0
	.disk_hdd				db 'hard drive', 0
	.disk_cdrom				db 'CD/DVD', 0
	.disk_unknown			db 'unknown', 0

	.failure0msg			db 'Filename is too long!', 0
	.failure1msg			db 'Filename is empty!', 0
	.failure2msg			db 'Filename has no extension!', 0
	.failure3msg			db 'Filename has no basename!', 0
	.failure4msg			db 'Extension is too short!', 0

	.fs_error				db 'Disk contains an invalid file system!', 0
	
	.dk_error				db 'Disk error!', 0
	
	.default_fs				db 'FAT12   ', 0
	
	.dstype_string_full		times 40 db 0
	
	.tmp_string1			times 15 db 0
	.tmp_string2			times 15 db 0

	.load_segment			dw 0
	.load_offset			dw 0
	
	.disk_buffer			equ	16384

	.screenstring			times 24 db 0

blank:
	
; ------------------------------------------------------------------
