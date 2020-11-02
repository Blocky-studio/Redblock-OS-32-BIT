; ------------------------------------------------------------------
; Program to test loading an app at 36864 (32768+4K)
; The big_buffer at the bottom is simply to create a bigger file.
; ------------------------------------------------------------------


	BITS 16
	%INCLUDE "mikedev.inc"
	ORG 36864	; <--------- note 36864 and not 32768

;=====================================================================
main_start:
;=====================================================================

	mov si, start_msg
	call os_print_string

	call os_wait_for_key
	call os_clear_screen
	ret

big_buffer	times 512 db 0	
start_msg	db	'This program is running at RAM location 36864',13,10,0