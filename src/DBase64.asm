;Binary to Text Decoder using Base64
.386
assume cs:cseg, ds:cseg
cseg segment 'code'

org 100h

START: jmp RealStart

;Data Section
Inname db 127 dup(?)
Outname db 127 dup(?)
InH dw (?)
OutH dw (?)
IBuff db 80 dup(?)
OBuff db 60 dup(?)
InBuff db 4 dup(?)
OutBuff db 3 dup(?)
ByteCount dw (?)
ErrParse db "Could not parse args. Please check."
ErrRead db "Could not read from input file."
ErrWrite db "Could not write to output file."
ErrMsgInp db "Could not open Input file. Please check."
ErrMsgOut db "Could not create Output file to write to. Please check."

RealStart:

;Setting Text Mode
mov ax, 03h
int 10h

cld; Clearing Direction Flag

;ParseIOFile
;Input File Name
assume es:cseg
mov di, offset Inname
mov si, 81h
L1:
lodsb
cmp al, ' '
JZ L1
cmp al, 9; tab
JZ L1
cmp al, 13; return
JZ Error
L2:
stosb
lodsb
cmp al, ' '
JZ L3
cmp al, 9
JZ L3
cmp al, 13
JZ Error
jmp L2
L3:
sub al, al
stosb

;Output File Name
mov di, offset Outname
L4:
lodsb
cmp al, ' '
JZ L4
cmp al, 9
JZ L4
cmp al, 13
JZ Error
L5:
stosb
lodsb
cmp al, 13
JZ L6
jmp L5
L6:
sub al, al
stosb
jmp Here

Error:
mov ax, 0b800h
mov es, ax
mov cx, 35
mov si, offset ErrParse
L7:
lodsb
mov es:[bx], al
add bx , 2
Loop L7
jmp Quit

Here:
mov ax, 0b800h
mov es, ax ; don't need ES to point to Cseg anymore, moving to Video Mem

;Open
Open:
mov ax, 3d00h; open in read mode
mov dx, offset Inname
int 21h
cld
JC IError
mov InH, ax
jmp Here2
IError:
mov cx, 40
sub bx, bx
mov si, offset ErrMsgInp
L8:
lodsb
mov es:[bx], al
add bx, 2
Loop L8
jmp Quit
Here2:

;Create
Create:
mov dx, offset Outname
mov ah, 3Ch; Create File
sub cx, cx; Normal mode
int 21h
JC OError
mov OutH, ax
jmp Here3
OError:
cld
mov cx, 55
sub bx, bx
mov si, offset ErrMsgOut
L0:
lodsb
mov es:[bx], al
add bx, 2
Loop L0
jmp Quit
Here3:

;Read 80 Bytes chunks : I was using 410 but noticed that carriage returns were not being parsed properly.
;It would have required me to completely rewrite. I had no time. So came up with this sloppy solution using 42h
Read:
mov ah, 3fh
mov bx, InH
mov dx, offset IBuff
mov cx, 80
int 21h
JC FRError
or ax, ax
JZ Done ; Read 0 bytes
mov ByteCount, ax

mov bx, InH
mov ah, 42h
mov al, 1
sub cx, cx
mov dx, 2
int 21h

sub di, di
sub bx, bx
L12:
	sub si, si
	mov cx, 4
	L13:
		mov al, IBuff[bx]
		mov InBuff[si], al
		inc bx
		inc si
	Loop L13
	sub si, si
	;Decode
	;1st Byte
	mov ah, InBuff[0]
	sub ah, 33
	mov al, InBuff[1]
	sub al, 33
	shl ah, 2
	shr al, 4
	or ah, al
	mov OutBuff[0], ah
	;2nd Byte
	cmp InBuff[2], 'z'
	JZ Pad2
	mov ah, InBuff[1]
	sub ah, 33
	mov al, InBuff[2]
	sub al, 33
	shl ah, 4
	shr al, 2
	or ah, al
	mov OutBuff[1], ah
	;3rd byte
	cmp InBuff[3], 'z'
	JZ Pad1
	mov ah, InBuff[2]
	sub ah, 33
	mov al, InBuff[3]
	sub al, 33
	shl ah, 6
	or ah, al
	mov OutBuff[2], ah
	jmp Proceed
	Pad1:
	mov OutBuff[2], 122
	jmp Proceed
	Pad2:
	mov OutBuff[1], 122
	mov OutBuff[2], 122
	;End Decode
	Proceed:
	mov cx, 3
	L14:
		cmp OutBuff[si], 122
		JZ skip1
		mov al, OutBuff[si]
		mov OBuff[di], al
		inc di
		skip1:
		inc si
	Loop L14
cmp bx, ByteCount
JB L12
mov ByteCount, di
mov ah, 40h
mov bx, OutH
mov dx, offset OBuff
mov cx, ByteCount
int 21h
JC FWError

jmp Read
;Else done with encoding
Done:
jmp Exit

FRError:
cld
mov cx, 31
sub bx, bx
mov si, offset ErrRead
L9:
lodsb
mov es:[bx], al;
add bx, 2
Loop L9
jmp Exit

FWError:
cld
mov cx, 32
sub bx, bx
mov si, offset ErrWrite
L10:
lodsb
mov es:[bx], al
add bx, 2
Loop L10
jmp Exit

Exit:
Close:
mov ah, 3Eh
mov bx, InH
int 21h
mov ah, 3Eh
mov bx, OutH
int 21h
Quit:
int 20h

cseg ends
end START
