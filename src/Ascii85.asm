;Binary to Text Encoder using Ascii85
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
IBuff db 400 dup(?)
OBuff db 510 dup(?)
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
Read:
mov ah, 3fh
mov bx, InH
mov dx, offset IBuff
mov cx, 400
int 21h
JC FRError
or ax, ax
JZ Done ; Read 0 bytes
mov ByteCount, ax

;Encode
mov cx, 100; going to check if bytecount is a multiple of 4
LL1: cmp ax, 4
JB NMulof4B
sub ax, 4
JZ Mulof4B
Loop LL1

NMulof4B:
mov dl, 4
sub dl, al; dl has count of pad bytes

Mulof4B:
sub di, di
sub bx, bx
sub dh, dh; I will use dh to count when to put CRLF
L11:
	inc dh
	sub eax, eax
	mov al, IBuff[bx]
	inc bx
	shl eax,8
	mov al, IBuff[bx]
	inc bx
	shl eax,8
	mov al, IBuff[bx]
	inc bx
	shl eax,8
	mov al, IBuff[bx]
	inc bx
	;Get the first byte converted:
	sub cl, cl; using subtraction. division is too bothersome
	L13:
		cmp eax, 52200625; 85^4
		jb fin4
		sub eax, 52200625
		inc cl
		jmp L13
	fin4:
	add cl, 33
	mov OBuff[di], cl
	inc di
	sub cl, cl
	L14:
		cmp eax, 614125; 85^3
		jb fin3
		sub eax, 614125
		inc cl
		jmp L14
	fin3:
	add cl, 33
	mov OBuff[di], cl
	inc di
	sub cl, cl
	L15:
		cmp eax, 7225; 85^2
		jb fin2
		sub eax, 7225
		inc cl
		jmp L15
	fin2:
	add cl, 33
	mov OBuff[di], cl
	inc di
	sub cl, cl
	L16:
		cmp eax, 85; 85^1
		jb fin1
		sub eax, 85
		inc cl
		jmp L16
	fin1:
	add cl, 33
	mov OBuff[di], cl
	inc di
	sub cl, cl
	;fin0
	add al, 33
	mov OBuff[di], al
	inc di

	cmp dh, 20; 80 bytes
	JZ CRLF
	jmp NCRLF
	CRLF:
	sub dh, dh
	mov OBuff[di], 0Dh
	inc di
	mov OBuff[di], 0Ah
	inc di
	NCRLF:
cmp bx, ByteCount
JB L11

cmp dl, 3
JZ Pad3
cmp dl, 2
JZ Pad2
cmp dl, 1
JZ Pad1
jmp normal

;Let x,y,z represent 3,2,1
Pad3:
mov OBuff[di], 'x'
inc di
jmp normal
Pad2:
mov OBuff[di], 'y'
inc di
jmp normal
Pad1:
mov OBuff[di], 'z'
inc di
;END ENCODE

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
