;Binary to Text Decoder using Ascii85
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
IBuff db 100 dup(?)
OBuff db 80 dup(?)
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
cld
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

;Read
;Once again, due to time constraints, had to skip CRLF similar way to base64.
;However, I sent through e-mail and it still works.
Read:
mov ah, 3fh
mov bx, InH
mov dx, offset IBuff
mov cx, 100
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
;Decode
sub di, di
sub bx, bx
L11:
	sub eax, eax
	sub edx, edx; edx will hold the decoded data
	FirByte:
	mov cl, IBuff[bx]
	inc bx
	cmp cl, 'x'; skip last three bytes
	jz unpad3
	cmp cl, 'y'; skip last two bytes
	jz unpad2
	cmp cl, 'z'; skip last byte
	jz unpad1
	sub cl, 33
	JZ SecByte
	L12:
	add eax, 52200625
	Loop L12
	add edx, eax

	SecByte:
	sub eax, eax
	mov cl, IBuff[bx]
	inc bx
	sub cl, 33
	JZ ThByte
	L13:
	add eax, 614125
	Loop L13
	add edx, eax

	ThByte:
	sub eax, eax
	mov cl, IBuff[bx]
	inc bx
	sub cl, 33
	JZ FouByte
	L14:
	add eax, 7225
	Loop L14
	add edx, eax

	FouByte:
	sub eax, eax
	mov cl, IBuff[bx]
	inc bx
	sub cl, 33
	JZ LasByte
	L15:
	add eax, 85
	Loop L15
	add edx, eax

	LasByte:
	sub eax, eax
	mov al, IBuff[bx]
	inc bx
	sub al, 33
	add edx, eax

	;Done edx has the 4 bytes; Could not do mov dword ptr OBuff[di], edx (Endianness?) So doing this
	mov eax, edx
	shr eax, 24
	mov OBuff[di], al
	inc di
	mov eax, edx
	shr eax, 16
	mov OBuff[di], al
	inc di
	mov OBuff[di], dh
	inc di
	mov OBuff[di], dl
	inc di
	cmp bx, ByteCount
JB L11
jmp normal

unpad3:
dec di
unpad2:
dec di
unpad1:
dec di

normal:
mov ByteCount, di
;Write
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
