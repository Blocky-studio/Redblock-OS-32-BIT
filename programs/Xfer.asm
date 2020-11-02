; =========================================================
; Xfer, a Xmodem based utility to enable the uploading of 
; compiled bin files to a Redblock OS computer.
; See help file first. (Xfer.htm)
; =========================================================

BITS 16


	%INCLUDE "mikedev.inc"
	ORG 32768

	push di
	mov ax, 36864
	mov di, ax
	mov ax, 0

	mov al, 0c3h	; opcode for RET
	mov [di], al	; put at begining incase called without
			; loading a bin file first.

	pop di

	call os_clear_screen

; ----------------------------------------------------------
start:
; ----------------------------------------------------------


	mov dx, 3fah		; com port's FIFO control REG.
	mov al, 11000111b	; clear buffers and enable 16 byte FIFO
	out dx, al

	mov si, msg_one
	call os_print_string
	mov si, msg_two
	call os_print_string

	mov ax, 0
	call os_wait_for_key

	cmp al, '1'
	je connect_fast

	cmp al, '2'
	je connect_slow

	cmp al, '3'
	je execute_bin_program

	cmp al, '4'
	je finish

	jmp start

; ----------------------------------------------------------
start_xfer:
; ----------------------------------------------------------

	mov dx, 3fah		; com port's FIFO control REG.
	mov al, 11000111b	; clear buffers and enable 16 byte FIFO
	out dx, al

	mov ax, 20		; wait a bit for the UART.
	call os_pause

	mov ax, 36864
	mov [ram_pointer], ax

	mov al, 0
	mov [byte_count], al
	mov al, 1
	mov [packet_count], al

	mov al, 15h			; tell sender we are ready
	call os_send_via_serial

get_header_byte_one:

	call rx_data_wait		
	jc get_header_byte_one		; Data received?
	
	call get_serial_byte		; get the data from al
	cmp al, 4			; 4 = EOT = DONE
	je download_done

	cmp al, 1			; 1 = SOH = a packet follows
	je get_header_byte_two
	jmp terminate_with_error	; anything else is an error, bail out

get_header_byte_two:

	call rx_data_wait
	jc get_header_byte_two
	call get_serial_byte		; get the packet number from al
	mov [packet_num], al

get_header_byte_three:

	call rx_data_wait
	jc get_header_byte_three
	call get_serial_byte		; get the complemented packet number from al
	mov [not_packet_num], al

	mov ax, 0
	mov si, ax

get_packet_data:			; get 128 bytes/packet

	call rx_data_wait
	jc get_packet_data

	mov al, [byte_count]
	inc al
	mov [byte_count], al
 
	call get_serial_byte		; get the data from al
	mov [temp_store+si], al		; store it for now
	
	inc si
	cmp si, 128
	jne get_packet_data

get_checksum:

	call rx_data_wait
	jc get_checksum

	call get_serial_byte		; get it from al
	mov [header_checksum], al

	; =============== Error checking if required goes here =====================

get_next_packet:

	mov ax, [ram_pointer]
	mov di, ax

	mov ax, 0
	mov si, ax		
	
.ram_update:

	mov al, [temp_store+si]
	mov [di], al
	inc si
	inc di
	cmp si, 128
	jne .ram_update
		
	mov [ram_pointer], di

	mov al, [packet_count]		; increment packet counter.
	inc al
	mov [packet_count], al

	mov al, 6			; send next packet.
	call os_send_via_serial		; 
	jmp get_header_byte_one

; ----------------------------------------------------------
download_done:
; ----------------------------------------------------------

	mov al, 6			; confirm EOT with ACK
	call os_send_via_serial

	call os_clear_screen

	mov si, msg_five
	call os_print_string

	jmp start

; ----------------------------------------------------------
get_serial_byte:
; ----------------------------------------------------------

	mov dx, 3f8h
	in al, dx
	ret

; ----------------------------------------------------------
rx_data_wait:
; ----------------------------------------------------------

	mov dx, 3fdh	; LSR reg of com1 base address+5
	in al, dx
	and al, 1	; bit 0 is high when data pending
	cmp al, 1
	ret

; ----------------------------------------------------------
connect_fast:
; ----------------------------------------------------------

	mov ah, 0ch	; baud rate =9600
	jmp enable_serial_port

; -----------------------------------------------------------
connect_slow:
; -----------------------------------------------------------

	mov ah, 60h	; baud rate =1200

; -----------------------------------------------------------
enable_serial_port:
; -----------------------------------------------------------

	mov dx, 3fbh	; set DLAB plus 8 bits, 1 stop bit etc
	mov al, 131
	out dx, al

	mov dx, 3f8h	; baud rate low reg when DLAB=1
	mov al, ah	; set either 9600 or 1200 baud
	out dx, al

	mov dx, 3f9h	; baud rate hi reg when DLAB=1
	mov al, 0
	out dx, al

	mov dx, 3fbh	; switch DLAB back to zero
	mov al, 3
	out dx, al

	mov dx, 3f9h	; disable all interupts
	mov al, 0
	out dx, al

	jmp start_xfer

; ----------------------------------------------------------
terminate_with_error:
; ----------------------------------------------------------

	push di
	mov ax, 36864
	mov di, ax
	mov ax, 0

	mov al, 0c3h	; opcode for RET
	mov [di], al	; put at begining so that uploaded file
			; which contains error/s cannot be run.

	pop di

	mov cx, 8

.send_term:

	mov al, 18h	; tell sender to terminate transfer by sending lots of 18h bytes.
	call os_send_via_serial

	loop .send_term

	call os_clear_screen

	mov si, msg_six
	call os_print_string

	jmp start	

; -----------------------------------------------------------
execute_bin_program:
; -----------------------------------------------------------

	call os_clear_screen		; Clear screen before running

	mov ax, 0			; Clear all registers
	mov bx, 0
	mov cx, 0
	mov dx, 0
	mov si, 0
	mov di, 0

	call 36864			; run it

; -----------------------------------------------------------
back_again:
; -----------------------------------------------------------

	jmp start

; -----------------------------------------------------------
finish:
; -----------------------------------------------------------

	ret

	msg_one		db	'Select an option from the menu below:',13,10,0
	msg_two		db	'1) Connect at 9600-N-8-1',13,10,'2) Connect at 1200-N-8-1',13,10,'3) Run uploaded bin file',13,10,'4) Exit',13,10,0
	msg_three	db	'Connecting....Please wait.',13,10,0
	msg_four	db	'Downloading....',13,10,0
	msg_five	db	'Download complete.',13,10,0
	msg_six		db	'Download error, please try again,',13,10,0

	byte_count		db	0
	packet_count		db	0
	first_header_byte	db	0
	header_checksum		db	0
	packet_num		db	0
	not_packet_num		db	0

	data_checksum		db	0
	repeat_packet_flag	db	0
	
	checksum_temp		dw	0
	ram_pointer		dw	0

	temp_store	times 128 db 0
