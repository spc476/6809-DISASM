;*************************************************************************
;
; Copyright 2013 by Sean Conner.
;
; This library is free software; you can redistribute it and/or modify it
; under the terms of the GNU Lesser General Public License as published by
; the Free Software Foundation; either version 3 of the License, or (at your
; option) any later version.
;
; This library is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
; License for more details.
;
; You should have received a copy of the GNU Lesser General Public License
; along with this library; if not, see <http://www.gnu.org/licenses/>.
;
; Comments, questions and criticisms can be sent to: sean@conman.org
;
;*************************************************************************
;
; This software is an MC6809 disassembler written in MC6809 assembly.  The
; code is position independent, so it can be placed anywhere in memory.  It
; is also read only, so it can be placed in ROM.  It uses 47 bytes of
; stackspace (including return address), and requires 55 bytes for output.
;
;	DISASM		Disassemble one instuction
;		Entry	X - at least 55 bytes of RAM
;			Y - address to decode
;		Exit	Y - next address to decode
;			all other registers preserved
;
;		NOTE:   The buffer is filled in with the following:
;
;			offset	contents
;			0	address in hex
;			2	opcode in hex
;			4	operand in hex
;			6	text representation of opcode
;			8	text representation of operands
;			10	ASCII strings
;
;			The strings are NUL byte terminated for your
;			convenience.
;=========================================================================

opsize		equ	3		; size of opcode informtion entry

	;--------------------------------------------------------------------
	; Values for addressing modes.  They're biased by 3 so we can
	; directly index a jump table to handle each mode, 3 because we long
	; branch to the apropriate routine (remember, we're position
	; independent code here).  By doing the precalculation we save a few
	; instructions.
	;--------------------------------------------------------------------

illegal		equ	 0 * 3		; addressing mode values
inherent	equ	 1 * 3		; no data
immediate	equ	 2 * 3		; data is part of instruction
direct		equ	 3 * 3		; data has 8 bit address
extended	equ	 4 * 3		; data has 16 bit address
indexed		equ	 5 * 3		; data is indexed off index register
relative	equ	 6 * 3		; one byte relative address
lrelative	equ	 7 * 3		; two byte relative address
page1		equ	 8 * 3		; page1 opcodes
page2		equ	 9 * 3		; page2 opcodes
exg		equ	10 * 3		; EXG, TFR
pushpull	equ	11 * 3		; PSHS, PULS, PSHU, PULU
imm16		equ	12 * 3		; 16bit immediate value

;=========================================================================

		org	$0000
init		lbra	disasm

;--------------------------------------------------------
; Text segment.  All strings here in are high-bit terminated (last character
; has high bit set).  This is all ASCII text, so this is okay, and it saves
; a ton of memory.
;
; NOTE: all the offsets to each string is less than 256, so we can use a
; single byte to point to a string.  Be careful if adding more text that you
; do not exceed offset 255 for the start of any string.
;---------------------------------------------------------------------------

tillegal	fcs	'ILLEGAL'
tabx		fcs	'ABX'
tadc		fcs	'ADC'
tadd		fcs	'ADD'
tand		fcs	'AND'
tasr		fcs	'ASR'
tbcc		fcs	'BCC'
tbcs		fcs	'BCS'
tbeq		fcs	'BEQ'
tbge		fcs	'BGE'
tbgt		fcs	'BGT'
tbhi		fcs	'BHI'
tbit		fcs	'BIT'
tble		fcs	'BLE'
tbls		fcs	'BLS'
tblt		fcs	'BLT'
tbmi		fcs	'BMI'
tbne		fcs	'BNE'
tbpl		fcs	'BPL'
tbra		fcs	'BRA'
tbrn		fcs	'BRN'
tbsr		fcs	'BSR'
tbvc		fcs	'BVC'
tbvs		fcs	'BVS'
tclr		fcs	'CLR'
tcmp		fcs	'CMP'
tcom		fcs	'COM'
tcwai		fcs	'CWAI'
tdaa		fcs	'DAA'
tdec		fcs	'DEC'
teor		fcs	'EOR'
texg		fcs	'EXG'
tinc		fcs	'INC'
tjmp		fcs	'JMP'
tjsr		fcs	'JSR'
tld		fcs	'LD'
tlea		fcs	'LEA'
tlsl		fcs	'LSL'
tlsr		fcs	'LSR'
tmul		fcs	'MUL'
tneg		fcs	'NEG'
tnop		fcs	'NOP'
tor		fcs	'OR'
tpsh		fcs	'PSH'
tpul		fcs	'PUL'
trol		fcs	'ROL'
tror		fcs	'ROR'
trti		fcs	'RTI'
trts		fcs	'RTS'
tsbc		fcs	'SBC'
tsex		fcs	'SEX'
tst		fcs	'ST'
tsub		fcs	'SUB'
tswi		fcs	'SWI'
tsync		fcs	'SYNC'
ttfr		fcs	'TFR'
ttst		fcs	'TST'

regA		equ	tbra + 2	; 'A'
regB		equ	tsub + 2	; 'B'
regDP		fcs	'DP'
regCC		equ	tbcc + 1	; 'CC'
regD		equ	tadd + 2	; 'D'
regX		equ	tabx + 2	; 'X'
regY		fcs	'Y'
regS		equ	tbcs + 2	; 'S'
regU		fcs	'U'
regPC		fcs	'PC'

sp		fcs	' '
t2		fcs	'2'
t3		fcs	'3'
unknown		fcs	'?'
tcm		fcs	',-'
tcmm		fcs	',--'
tbr		fcs	'B,'
tar		fcs	'A,'
tdr		fcs	'D,'

indexreg	fcb	regX	,regY	,regU	,regS

exgtfr		fcb	regD	,regX	,regY	,regU
		fcb	regS	,regPC	,unknown,unknown
		fcb	regA	,regB	,regCC	,regDP
		fcb	unknown,unknown,unknown,unknown

pshpultab	fcb	regPC	,0	,regY	,regX
		fcb	regDP	,regB	,regA	,regCC

;----------------------------------------------------------------------
; Opcode tables.  The main table has the following structure:
;
;	addressing mode
;	opcode text
;	additional opcode text	
;----------------------------------------------------------------------

ops		fcb	direct		,tneg		,sp	; $00
		fcb	illegal		,tillegal	,sp
		fcb	illegal		,tillegal	,sp
		fcb	direct		,tcom		,sp
		fcb	direct		,tlsr		,sp
		fcb	illegal		,tillegal	,sp
		fcb	direct		,tror		,sp
		fcb	direct		,tasr		,sp
		fcb	direct		,tlsl		,sp
		fcb	direct		,trol		,sp
		fcb	direct		,tdec		,sp
		fcb	illegal		,tillegal	,sp
		fcb	direct		,tinc		,sp
		fcb	direct		,ttst		,sp
		fcb	direct		,tjmp		,sp
		fcb	direct		,tclr		,sp

		fcb	page1		,sp		,sp	; $10
		fcb	page2		,sp		,sp
		fcb	inherent	,tnop		,sp
		fcb	inherent	,tsync		,sp
		fcb	illegal		,tillegal	,sp
		fcb	illegal		,tillegal	,sp
		fcb	lrelative	,tbra		,sp
		fcb	lrelative	,tbsr		,sp
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tdaa		,sp
		fcb	immediate	,tor		,regCC
		fcb	illegal		,tillegal	,sp
		fcb	immediate	,tand		,regCC
		fcb	inherent	,tsex		,sp
		fcb	exg		,texg		,sp
		fcb	exg		,ttfr		,sp

		fcb	relative	,tbra		,sp	; $20
		fcb	relative	,tbrn		,sp
		fcb	relative	,tbhi		,sp
		fcb	relative	,tbls		,sp
		fcb	relative	,tbcc		,sp
		fcb	relative	,tbcs		,sp
		fcb	relative	,tbne		,sp
		fcb	relative	,tbeq		,sp
		fcb	relative	,tbvc		,sp
		fcb	relative	,tbvs		,sp
		fcb	relative	,tbpl		,sp
		fcb	relative	,tbmi		,sp
		fcb	relative	,tbge		,sp
		fcb	relative	,tblt		,sp
		fcb	relative	,tbgt		,sp
		fcb	relative	,tble		,sp

		fcb	indexed		,tlea		,regX	; $30
		fcb	indexed		,tlea		,regY
		fcb	indexed		,tlea		,regS
		fcb	indexed		,tlea		,regU
		fcb	pushpull	,tpsh		,regS
		fcb	pushpull	,tpul		,regS
		fcb	pushpull	,tpsh		,regU
		fcb	pushpull	,tpul		,regU
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,trts		,sp
		fcb	inherent	,tabx		,sp
		fcb	inherent	,trti		,sp
		fcb	immediate	,tcwai		,sp
		fcb	inherent	,tmul		,sp
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tswi		,sp

		fcb	inherent	,tneg		,regA	; $40
		fcb	illegal		,tillegal	,sp
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tcom		,regA
		fcb	inherent	,tlsr		,regA
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tror		,regA
		fcb	inherent	,tasr		,regA
		fcb	inherent	,tlsl		,regA
		fcb	inherent	,trol		,regA
		fcb	inherent	,tdec		,regA
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tinc		,regA
		fcb	inherent	,ttst		,regA
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tclr		,regA

		fcb	inherent	,tneg		,regB	; $50
		fcb	illegal		,tillegal	,sp
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tcom		,regB
		fcb	inherent	,tlsr		,regB
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tror		,regB
		fcb	inherent	,tasr		,regB
		fcb	inherent	,tlsl		,regB
		fcb	inherent	,trol		,regB
		fcb	inherent	,tdec		,regB
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tinc		,regB
		fcb	inherent	,ttst		,regB
		fcb	illegal		,tillegal	,sp
		fcb	inherent	,tclr		,regB

		fcb	indexed		,tneg		,sp	; $60
		fcb	illegal		,tillegal	,sp
		fcb	illegal		,tillegal	,sp
		fcb	indexed		,tcom		,sp
		fcb	indexed		,tlsr		,sp
		fcb	illegal		,tillegal	,sp
		fcb	indexed		,tror		,sp
		fcb	indexed		,tasr		,sp
		fcb	indexed		,tlsl		,sp
		fcb	indexed		,trol		,sp
		fcb	indexed		,tdec		,sp
		fcb	illegal		,tillegal	,sp
		fcb	indexed		,tinc		,sp
		fcb	indexed		,ttst		,sp
		fcb	indexed		,tjmp		,sp
		fcb	indexed		,tclr		,sp

		fcb	extended	,tneg		,sp	; $70
		fcb	illegal		,tillegal	,sp
		fcb	illegal		,tillegal	,sp
		fcb	extended	,tcom		,sp
		fcb	extended	,tlsr		,sp
		fcb	illegal		,tillegal	,sp
		fcb	extended	,tror		,sp
		fcb	extended	,tasr		,sp
		fcb	extended	,tlsl		,sp
		fcb	extended	,trol		,sp
		fcb	extended	,tdec		,sp
		fcb	illegal		,tillegal	,sp
		fcb	extended	,tinc		,sp
		fcb	extended	,ttst		,sp
		fcb	extended	,tjmp		,sp
		fcb	extended	,tclr		,sp

		fcb	immediate	,tsub		,regA	; $80
		fcb	immediate	,tcmp		,regA
		fcb	immediate	,tsbc		,regA
		fcb	imm16		,tsub		,regD
		fcb	immediate	,tand		,regA
		fcb	immediate	,tbit		,regA
		fcb	immediate	,tld		,regA
		fcb	illegal		,tillegal	,sp
		fcb	immediate	,teor		,regA
		fcb	immediate	,tadc		,regA
		fcb	immediate	,tor		,regA
		fcb	immediate	,tadd		,regA
		fcb	imm16		,tcmp		,regX
		fcb	relative	,tbsr		,sp
		fcb	imm16		,tld		,regX
		fcb	illegal		,tillegal	,sp

		fcb	direct		,tsub		,regA	; $90
		fcb	direct		,tcmp		,regA
		fcb	direct		,tsbc		,regA
		fcb	direct		,tsub		,regD
		fcb	direct		,tand		,regA
		fcb	direct		,tbit		,regA
		fcb	direct		,tld		,regA
		fcb	direct		,tst		,regA
		fcb	direct		,teor		,regA
		fcb	direct		,tadc		,regA
		fcb	direct		,tor		,regA
		fcb	direct		,tadd		,regA
		fcb	direct		,tcmp		,regX
		fcb	direct		,tjsr		,sp
		fcb	direct		,tld		,regX
		fcb	direct		,tst		,regX

		fcb	indexed		,tsub		,regA	; $A0
		fcb	indexed		,tcmp		,regA
		fcb	indexed		,tsbc		,regA
		fcb	indexed		,tsub		,regD
		fcb	indexed		,tand		,regA
		fcb	indexed		,tbit		,regA
		fcb	indexed		,tld		,regA
		fcb	indexed		,tst		,regA
		fcb	indexed		,teor		,regA
		fcb	indexed		,tadc		,regA
		fcb	indexed		,tor		,regA
		fcb	indexed		,tadd		,regA
		fcb	indexed		,tcmp		,regX
		fcb	indexed		,tjsr		,sp
		fcb	indexed		,tld		,regX
		fcb	indexed		,tst		,regX

		fcb	extended	,tsub		,regA	; $B0
		fcb	extended	,tcmp		,regA
		fcb	extended	,tsbc		,regA
		fcb	extended	,tsub		,regD
		fcb	extended	,tand		,regA
		fcb	extended	,tbit		,regA
		fcb	extended	,tld		,regA
		fcb	extended	,tst		,regA
		fcb	extended	,teor		,regA
		fcb	extended	,tadc		,regA
		fcb	extended	,tor		,regA
		fcb	extended	,tadd		,regA
		fcb	extended	,tcmp		,regX
		fcb	extended	,tjsr		,sp
		fcb	extended	,tld		,regX
		fcb	extended	,tst		,regX

		fcb	immediate	,tsub		,regB	; $C0
		fcb	immediate	,tcmp		,regB
		fcb	immediate	,tsbc		,regB
		fcb	imm16		,tadd		,regD
		fcb	immediate	,tand		,regB
		fcb	immediate	,tbit		,regB
		fcb	immediate	,tld		,regB
		fcb	illegal		,tillegal	,sp
		fcb	immediate	,teor		,regB
		fcb	immediate	,tadc		,regB
		fcb	immediate	,tor		,regB
		fcb	immediate	,tadd		,regB
		fcb	imm16		,tld		,regD
		fcb	illegal		,tillegal	,sp
		fcb	imm16		,tld		,regU
		fcb	illegal		,tillegal	,sp

		fcb	direct		,tsub		,regB	; $D0
		fcb	direct		,tcmp		,regB
		fcb	direct		,tsbc		,regB
		fcb	direct		,tadd		,regD
		fcb	direct		,tand		,regB
		fcb	direct		,tbit		,regB
		fcb	direct		,tld		,regB
		fcb	direct		,tst		,regB
		fcb	direct		,teor		,regB
		fcb	direct		,tadc		,regB
		fcb	direct		,tor		,regB
		fcb	direct		,tadd		,regB
		fcb	direct		,tld		,regD
		fcb	direct		,tst		,regD
		fcb	direct		,tld		,regU
		fcb	direct		,tst		,regU

		fcb	indexed		,tsub		,regB	; $E0
		fcb	indexed		,tcmp		,regB
		fcb	indexed		,tsbc		,regB
		fcb	indexed		,tadd		,regD
		fcb	indexed		,tand		,regB
		fcb	indexed		,tbit		,regB
		fcb	indexed		,tld		,regB
		fcb	indexed		,tst		,regB
		fcb	indexed		,teor		,regB
		fcb	indexed		,tadc		,regB
		fcb	indexed		,tor		,regB
		fcb	indexed		,tadd		,regB
		fcb	indexed		,tld		,regD
		fcb	indexed		,tst		,regD
		fcb	indexed		,tld		,regU
		fcb	indexed		,tst		,regU

		fcb	extended	,tsub		,regB	; $F0
		fcb	extended	,tcmp		,regB
		fcb	extended	,tsbc		,regB
		fcb	extended	,tadd		,regD
		fcb	extended	,tand		,regB
		fcb	extended	,tbit		,regB
		fcb	extended	,tld		,regB
		fcb	extended	,tst		,regB
		fcb	extended	,teor		,regB
		fcb	extended	,tadc		,regB
		fcb	extended	,tor		,regB
		fcb	extended	,tadd		,regB
		fcb	extended	,tld		,regD
		fcb	extended	,tst		,regD
		fcb	extended	,tld		,regU
		fcb	extended	,tst		,regU

;---------------------------------------------------------------------
; Extended opcode information.  The structure here is:
;
;	2nd byte of opcode
;	addressing mode
;	text of opcode
;	additional text for opcode
;---------------------------------------------------------------------

opsp1		fcb	$21,lrelative	,tbrn		,sp
		fcb	$22,lrelative	,tbhi		,sp
		fcb	$23,lrelative	,tbls		,sp
		fcb	$24,lrelative	,tbcc		,sp
		fcb	$25,lrelative	,tbcs		,sp
		fcb	$26,lrelative	,tbne		,sp
		fcb	$27,lrelative	,tbeq		,sp
		fcb	$28,lrelative	,tbvc		,sp
		fcb	$29,lrelative	,tbvs		,sp
		fcb	$2A,lrelative	,tbpl		,sp
		fcb	$2B,lrelative	,tbmi		,sp
		fcb	$2C,lrelative	,tbge		,sp
		fcb	$2D,lrelative	,tblt		,sp
		fcb	$2E,lrelative	,tbgt		,sp
		fcb	$2F,lrelative	,tble		,sp
		fcb	$3F,inherent	,tswi		,t2
		fcb	$83,imm16	,tcmp		,regD
		fcb	$8C,imm16	,tcmp		,regY
		fcb	$8E,imm16	,tld		,regY
		fcb	$93,direct	,tcmp		,regD
		fcb	$9C,direct	,tcmp		,regY
		fcb	$9E,direct	,tld		,regY
		fcb	$9F,direct	,tst		,regY
		fcb	$A3,indexed	,tcmp		,regD
		fcb	$AC,indexed	,tcmp		,regY
		fcb	$AE,indexed	,tld		,regY
		fcb	$AF,indexed	,tst		,regY
		fcb	$B3,extended	,tcmp		,regD
		fcb	$BC,extended	,tcmp		,regY
		fcb	$BE,extended	,tld		,regY
		fcb	$BF,extended	,tst		,regY
		fcb	$CE,imm16	,tld		,regS
		fcb	$DE,direct	,tld		,regS
		fcb	$DF,direct	,tst		,regS
		fcb	$EE,indexed	,tld		,regS
		fcb	$EF,indexed	,tst		,regS
		fcb	$FE,extended	,tld		,regS
		fcb	$FF,extended	,tst		,regS
		fcb	$00,illegal	,tillegal	,sp

opsp2		fcb	$3F,inherent	,tswi		,t3
		fcb	$83,imm16	,tcmp		,regU
		fcb	$8C,imm16	,tcmp		,regS
		fcb	$93,direct	,tcmp		,regU
		fcb	$9C,direct	,tcmp		,regS
		fcb	$A3,indexed	,tcmp		,regU
		fcb	$AC,indexed	,tcmp		,regS
		fcb	$B3,extended	,tcmp		,regU
		fcb	$BC,extended	,tcmp		,regS
		fcb	$00,illegal	,tillegal	,sp

;--------------------------------------------------------

jmptab		lbra	fillegal
		lbra	finherent
		lbra	fimmediate
		lbra	fdirect
		lbra	fextended
		lbra	findexed
		lbra	frelative
		lbra	flrelative
		lbra	fpage1
		lbra	fpage2
		lbra	fexg
		lbra	fpushpull
		lbra	fimm16

;--------------------------------------------------------
;	DISASM
;Entry:	X - buffer of 55 bytes
;	Y - address to disassemble
;Exit:	Y - next address 
;	All others saved
;--------------------------------------------------------

theaddr		equ	 6		; Y being passed in
paddr		equ	-2
popcode		equ	-4
poperand	equ	-6
ptopcode	equ	-8
ptoperand	equ	-10
indexidx	equ	-11
opbyte		equ	-12
thepage		equ	-13
bufsiz		equ	45

disasm		pshs	u,y,x,dp,a,b,cc	; save registers
		tfr	s,y		; using Y to reference locals
		leas	-13,s		; local vars

		tfr	x,u
		leax	10,x
		stx	,u++
		stx	paddr,y		; initialize local vars
		leax	5,x
		stx	,u++
		stx	popcode,y
		leax	5,x
		stx	,u++
		stx	poperand,y
		leax	7,x
		stx	,u++
		stx	ptopcode,y
		leax	9,x
		stx	,u++
		stx	ptoperand,y
		clr	indexidx,y
		clr	opbyte,y

		ldx	paddr,y		; get text buffers
		ldd	#bufsiz		; A = 0 ,B = count
disasm10	sta	,x+		; clear buffer space
		decb			; more?
		bne	disasm10

		lda	#opsize		; size of structure
		ldb	[theaddr,y]	; get opcode
		leax	ops,pc		; get ops table
		mul			; calculate offset
		leax	d,x		; point to entry
		lbsr	caddroptop	; print addr, op, text op
		leau	jmptab,pc	; get jump table
		lda	,x		; get entry
		jsr	a,u		; call entry

		tfr	y,s		; clean up local var space
		puls	cc,b,a,dp,u,x,y,pc

;--------------------------------------------------------
;	FPAGE1		Handle page1 op
;Entry: X - opcode entry
;	X - instruction data
;Exit:	Y - unmodified
;--------------------------------------------------------

fpage1		lda	#$10		; we're page 1
		leax	opsp1,pc	; table of page1 opcodes

fpagerest	sta	thepage,y	; save for later
		lda	[theaddr,y]	; get 2nd opcode byte
		bsr	findop		; find entry
		lbsr	coptop		; fill out text fields
		leau	jmptab,pc	; pointer to instruction type 
		lda	,x		; get instruction type
		jsr	a,u		; handle it

		ldu	popcode,y	; insert space for page op
		ldd	,u		; get hex value
		std	2,u		; shift over two spaces
		lda	thepage,y	; get page op
		lbra	phex2		; print it

;--------------------------------------------------------
;	FPAGE2		Handle page1 op
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

fpage2		lda	#$11		; we're page 2
		leax	opsp2,pc	; table of page2 opcodes
		bra	fpagerest	; handle as per page1

;--------------------------------------------------------
;	FINDOP		Find page op
;Entry:	X - page opcode array
;	A - opcode
;Exit:	X - page opcode entry
;--------------------------------------------------------

findop		tst	1,x		; invalid instruction?
		beq	findopfound	; if so, we're done
		cmpa	,x		; proper opcode?
		beq	findopfound	; if so, we're done
		leax	4,x		; point to next entry
		bra	findop
findopfound	leax	1,x		; skip past opcode byte

;--------------------------------------------------------
;	FILLEGAL		decode illegal opcodes
;	FINHERENT		decode inherent opcodes
;Entry	X - opcode entry
;	Y - local vars
;Exit	Y - unmodified
;--------------------------------------------------------

fillegal			; we treat illegal ops as inherent
finherent	rts		; nothing to do here citizen, move along!

;--------------------------------------------------------
;	FIMMEDIATE		decode immediate opcodes
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

fimmediate	lda	[theaddr,y]
		ldu	poperand,y
		lbsr	phex2
		ldu	ptoperand,y
		lda	#'#
		sta	,u+
gbap		lbsr	getibyte
		lbra	phex2

;--------------------------------------------------------
;	FIMM16			decode immediate 16b opcodes
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

fimm16		ldd	[theaddr,y]
		ldu	poperand,y
		lbsr	phex4d
		ldu	ptoperand,y
		lda	#'#
		sta	,u+
gwap		lbsr	getiword
		lbra	phex4d

;--------------------------------------------------------
;	FDIRECT		Handle direct mode instructions
;Entry:	X - instruction entry
;	Y - operand byte
;Exit:	Y - unmodified
;--------------------------------------------------------

fdirect		lda	[theaddr,y]
		ldu	poperand,y
		lbsr	phex2
		ldu	ptoperand,y
		bra	gbap

;--------------------------------------------------------
;	FEXTENDED	Handle extended mode instructions
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

fextended	ldd	[theaddr,y]
		ldu	poperand,y
		lbsr	phex4d
		ldu	ptoperand,y
		bra	gwap

;--------------------------------------------------------
;	FINDEXED	Handle indexed mode instructions
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;
; NOTE:	Yes, this function is ugly, but so is decoding
;	the indexed addressing mode.  Ugh.
;--------------------------------------------------------

findexed	ldu	poperand,y
		lbsr	getibyte
		sta	opbyte,y	; save operand byte
		lbsr	phex2
		lda	opbyte,y	; get operand byte
		rola			; isolate register bits
		rola
		rola
		rola
		anda	#3
		sta	indexidx,y	; save index register 
		lda	opbyte,y	; again, get operand byte
		bmi	findexfull	; the full monty

		bita	#$10		; is our offset negative?
		bne	findex10	; if so, handle
		anda	#$1F		; make positive
		fcb	$8C		; skip next instruction
findex10	ora	#$E0		; make negative
		ldu	ptoperand,y	; print negative offset
		lbsr	sphex2
		lda	#',		; comma
		sta	,u+
		leax	indexreg,pc	; and now register
		lda	indexidx,y	; get index
		ldb	a,x		; get string representing index reg
		lbra	strcpy		; print and return

	;---------

findexfull	ldu	ptoperand,y
		anda	#$0F		; isolate last four bits
		lsla			; convert into index
		leax	<fijmptab,pc	; and jump to appropriate routine
		jsr	a,x

		lda	opbyte,y	; get operand byte
		cmpu	ptoperand,y	; anything printed?
		beq	findexdone	; yup, we're done
		bita	#$10		; indirect?
		beq	findexdone	; nope

		lda	#']		; othersise, we need to add []
		sta	,u+		; around text

slidetext	lda	,-u		; slide text over one character
		sta	1,u
		cmpu	ptoperand,y
		bne	slidetext
		lda	#'[		; add leading [
		sta	,u
findexdone	rts

firp		lda	opbyte,y	; get operand byte
		bita	#$10		; indirect bit illegal
		bne	fidxill		; so handle
fripnt		lda	#',		; display comma
		sta	,u+
		lda	indexidx,y	; get index reg
		leax	indexreg,pc	; table of index registers
		ldb	a,x		; get string
		lbsr	strcpy		; print it
		lda	#'+		; add +
		sta	,u+
		rts

	; -----------

fijmptab	bra	firp		; ,R+
		bra	firpp		; ,R++
		bra	fimp		; ,-R
		bra	fimmp		; ,--R
		bra	fir		; ,R
		bra	fibr		; A,r
		bra	fiar		; B,r
		bra	fidxill		; illegal
		bra	fi7r		; 12,R
		bra	fi15r		; 1234,R
		bra	fidxill		; illegal
		bra	fidr		; D,r
		bra	fi7pc		; 12,PC
		bra	fi15pc		; 1234,PC
		bra	fidxill		; illegal
		bra	fiaddr		; [address]

	;----------------

firpp		bsr	fripnt		; handle the ,R+
		sta	,u+		; and add the final +
		rts

fimp		lda	opbyte,y	; get operand byte
		bita	#$10		; check indirect bit
		bne	fidxill		; if there, illegal
		ldb	#tcm		; get ,-
		lbsr	strcpy		; print it
fimpfinish	lda	indexidx,y	; get index reg
		leax	indexreg,pc	; table of index registers
		ldb	a,x		; get string
		lbra	strcpy		; print it

fimmp		ldb	#tcmm		; handle ,--
		lbsr	strcpy		; print it
		bra	fimpfinish	; finish up

fir		lda	#',		; handle ,
		sta	,u+
		bra	fimpfinish	; finish with register

fibr		ldb	#tbr		; get B,R
		bra	fiarfinish

fiar		ldb	#tar		; get A,R
		bra	fiarfinish

fidxill		ldu	ptopcode,y	; illegal mode, print as opcode
		ldb	#tillegal
		lbsr	strcpy
		ldu	ptoperand,y	; and return ptoperand
		rts

fi7r		bsr	fi7off		; print 7bit offset
		bra	fimpfinish	; and register

fi15r		bsr	fi15off		; print 15bit offset
		bra	fimpfinish	; and register

fidr		ldb	#tdr		; get D,R
fiarfinish	lbsr	strcpy
		leax	indexreg,pc
		lda	indexidx,y
		ldb	a,x
		lbra	strcpy

fi7pc		lbsr	getibyte	; handle +-7b,PC
		bsr	fiopr8
		tfr	a,b
		sex
		bra	fipcdone
fi15pc		lbsr	getiword	; handle +-15b,PC
		bsr	fiopr16
fipcdone	addd	theaddr,y	; relative to PC
		lbsr	phex4d		; print it
		bsr	fioffdone
		ldb	#regPC
		lbra	strcpy

fiaddr		lbsr	getiword	; get address
		bsr	fiopr16		; print operand bytes
		tst	indexidx,y	; only 00 (or X) supported
		bne	fidxill		; anything else is illegal
		lbra	phex4d		; brackets added later

fi7off		lbsr	getibyte	; get byte
		bsr	fiopr8
		lbsr	sphex2		; print signed hex
		bra	fioffdone	; continue
fi15off		lbsr	getiword	; get word
		bsr	fiopr16
		lbsr	sphex4		; print signed word
fioffdone	lda	#',		; add comma
		sta	,u+
		rts

fiopr8		pshs	u,d		; save print pos and D
		ldu	poperand,y	; add additional operand byte
		leau	2,u		; (skip past what we have)
		lbsr	phex2		; print byte
		puls	d,u,pc

fiopr16		pshs	u,d		; save print pos
		ldu	poperand,y	; add addtional operand bytes
		leau	2,u		; (skip past what we have)
		lbsr	phex4d		; print word
		puls	d,u,pc

;--------------------------------------------------------
;	FRELATIVE	Handle branch instructions
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

frelative	lda	[theaddr,y]
		ldu	poperand,y
		lbsr	phex2
		ldu	ptoperand,y
		lbsr	getibyte
		tfr	a,b
		sex
		bra	frelptraddr

;--------------------------------------------------------
;	FLRELATIVE	Handle long branch instructions
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

flrelative	ldu	ptopcode,y	; shift text opcode
		ldd	1,u		; over one character
		std	2,u		l so we can insert
		ldb	,u		; the 'L' character
		lda	#'L
		std	,u

		ldd	[theaddr,y]
		ldu	poperand,y
		lbsr	phex4d

		ldu	ptoperand,y
		bsr	getiword
frelptraddr	addd	theaddr,y
		lbra	phex4d

;--------------------------------------------------------
;	FEXG		Handle EXG,TFR instruction
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

fexg		ldu	poperand,y
		lda	[theaddr,y]
		lbsr	phex2
		leax	exgtfr,pc
		ldu	ptoperand,y
		lda	[theaddr,y]
		lsra
		lsra
		lsra
		lsra
		ldb	a,x
		lbsr	strcpy
		lda	#',
		sta	,u+
		bsr	getibyte
		anda	#$0F
		ldb	a,x
		lbra	strcpy

;--------------------------------------------------------
;	FPUSHPULL	Handle PSHS/PULS/PSHU/PULU instructions
;Entry:	X - opcode entry
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

fpushpull	ldu	theaddr,y	; get opcode
		lda	-1,u
		cmpa	#$35		; PSHS,PULS?
		ble	fpushpulls
		ldb	#regS
		fcb	$8C		; skip next instruction
fpushpulls	ldb	#regU
		stb	,-s		; save register name

		ldu	poperand,y
		lda	[theaddr,y]
		bsr	phex2
		leax	pshpultab,pc
		ldu	ptoperand,y
		bsr	getibyte
		ldb	#8

fpushpull10	rora
		bcc	fpushpull50
		pshs	d
		decb
		ldb	b,x
		bne	fpushpull20
		ldb	2,s
fpushpull20	bsr	strcpy
		lda	#',
		sta	,u+
		puls	d
fpushpull50	decb
		bne	fpushpull10

	;-------------------------------------------------------------------
	; if the operand byte is 0, no registers were saved/resotred, and
	; there's no trailing ','.  Check to see if we have a trailing comma
	; and if so, remove it.
	;-------------------------------------------------------------------

		lda	-1,u
		cmpa	#',
		bne	fpushpullexit
		clr	,-u

fpushpullexit	puls	a,pc

;--------------------------------------------------------
;	GETIBYTE	Get the next insrtruction byte
;Entry:	none
;Exit:	A - next instruction byte
;NOTE:	the address pointer is incremented
;--------------------------------------------------------

getibyte	pshs	u
		ldu	theaddr,y
		lda	,u+
		stu	theaddr,y
		puls	u,pc

;--------------------------------------------------------
;	GETIWORD	Get the next instruction word
;Entry:	none
;Exit:	D - next instruction word
;NOTE:	the address pointer is incremented by two
;--------------------------------------------------------

getiword	pshs	u
		ldu	theaddr,y
		ldd	,u++
		stu	theaddr,y
		puls	u,pc

;--------------------------------------------------------
;	CADDROPTOP	Print address, opcode byte and opcode
;Entry:	X - instruction info
;	Y - local vars
;Exit:	Y - unmodified
;--------------------------------------------------------

caddroptop	ldu	paddr,y	; print address
		ldd	theaddr,y
		bsr	phex4d
coptop		ldu	popcode,y	; print opcode
		bsr	getibyte
		bsr	phex2
		ldu	ptopcode,y	; print text of opcode
		ldb	1,x
		bsr	strcpy
		ldb	2,x		; plus any suffixes
		bra	strcpy

;--------------------------------------------------------
;	SPHEX2		Display a signed byte as hex
;Entry:	A - byte
;	U - buffer
;Exit:	U - U + 2
;--------------------------------------------------------

sphex2		tsta			; negative?
		bpl	phex2		; nope
		ldb	#'-		; print leading minus
		stb	,u+
		nega			; negate A
		bra	phex2		; and print

;--------------------------------------------------------
;	SPHEX4		Display a signed word as hex	; MOVE prior to phex4
;Entry:	D - word
;	U - buffer
;Exit:	U - U + 4
;--------------------------------------------------------

sphex4		tsta			; negative?
		bpl	phex4d		; nope
		stb	,-s		; save B
		ldb	#'-		; print leading minus
		stb	,u+
		ldb	,s+
		coma			; negate D
		comb
		addd	#1

;--------------------------------------------------------
;	PHEX4D		Display word
;Entry:	U - buffer
;       D - word
;Exit:	U - U + 4
;	D - trashed
;--------------------------------------------------------

phex4d		bsr	phex2		; print high byte
		tfr	b,a		; now get low byte

;--------------------------------------------------------
;	PHEX2		Display a byte as hex
;Entry:	A - byte
;	U - buffer
;Exit:	A - trashed
;	U - U + 2
;--------------------------------------------------------

phex2		sta	,-s		; save A
		lsra			; isolate upper nibble
		lsra
		lsra
		lsra
		bsr	phex		; print it
		lda	,s+		; restore A
phex		anda	#$0F		; isolate lower nibble
		adda	#$90		; use Allison's method
		daa			; to conver nibble to
		adca	#$40		; ASCII hex digit
		daa
		sta	,u+		; print
		rts

;--------------------------------------------------------
;	STRCPY		Copy high-bit terminated string
;Entry: B - string
;	U - dest
;Exit:	U - end of string
;	B - saved
;--------------------------------------------------------

strcpy		pshs	a,x
		leax	init,pc
		abx			; add in offset
strcpy10	lda	,x+
		bmi	strcpydone
		sta	,u+
		bra	strcpy10
strcpydone	anda	#$7F		; mask of ending bit
		sta	,u+		; write it out
		puls	a,x,pc		; return

;--------------------------------------------------------

		fcc	'      ' ; the rest on gift certificate
		fcc	'          LGPL3+'
		fcc	' sean@conman.org'

zzlast		equ	*
