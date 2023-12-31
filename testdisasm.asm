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
; This is just to test the disassembler, it's not meant to run.

	; $00 - $0F
		neg	$00
		fcb	$01
		fcb	$02
		com	$03
		lsr	$04
		fcb	$05
		ror	$06
		asr	$07
		lsl	$08
		rol	$09
		dec	$0A
		fcb	$0B
		inc	$0C
		tst	$0D
		jmp	$0E
		clr	$0F

	; page 1 opcodes
		lbrn	* + $1021 + 4
		lbhi	* + $1022 + 4
		lbls	* + $1023 + 4
		lbcc	* + $1024 + 4
		lbhs	* + $1024 + 4
		lbcs	* + $1025 + 4
		lblo	* + $1025 + 4
		lbne	* + $1026 + 4
		lbeq	* + $1027 + 4
		lbvc	* + $1028 + 4
		lbvs	* + $1029 + 4
		lbpl	* + $102A + 4
		lbmi	* + $102B + 4
		lbge	* + $102C + 4
		lblt	* + $102D + 4
		lbgt	* + $102E + 4
		lble	* + $102F + 4
		swi2
		cmpd	#$1083
		cmpy	#$108C
		ldy	#$108E
		cmpd	$93
		cmpy	$9C
		ldy	$9E
		sty	$9F
		cmpd	,x
		cmpy	,y
		ldy	,y
		sty	,y
		cmpd	$10B3
		cmpy	$10BC
		ldy	$10BE
		sty	$10BF
		lds	#$10CE
		lds	$DE
		sts	$DF
		lds	[$10EE]
		sts	[$10EF]
		lds	$10FE
		sts	$10FF
		fdb	$1050
		fcb	$10,$EE,$87

	; page 2 opcodes
		swi3
		cmpu	#$1183
		cmps	#$118C
		cmpu	$93
		cmps	$9C
		cmpu	,--y
		cmps	-84,y
		cmpu	$11B3
		cmps	$11BC
		fdb	$1150
		fcb	$11,$AC,$87

	; $10 - $1F
		nop
		sync
		fcb	$14
		fcb	$15
		lbra	* + $1616 + 3
		lbsr	* + $1717 + 3
		fcb	$18
		daa
		orcc	#$1A
		fcb	$1B
		andcc	#$1C
		sex
		exg	a,a
		fcb	$1E,$81 ; exg a,x
		fcb	$1E,$18 ; exg x,a
		fcb	$1E,$C1 ; exg ?,x
		fcb	$1E,$1C ; exg x,?
		tfr	x,x

	; $20-$2F
		bra	* + $20 + 2
		brn	* + $21 + 2
		bhi	* + $22 + 2
		bls	* + $23 + 2
		bcc	* + $24 + 2
		bhs	* + $24 + 2
		bcs	* + $25 + 2
		blo	* + $25 + 2
		bne	* + $26 + 2
		beq	* + $27 + 2
		bvc	* + $28 + 2
		bvs	* + $29 + 2
		bpl	* + $2A + 2
		bmi	* + $2B + 2
		bge	* + $2C + 2
		blt	* + $2D + 2
		bgt	* + $2E + 2
		ble	* + $2F + 2

	; $30-3F
		leax	[$3030]
		leay	[$3131]
		leas	[$3232]
		leau	[$3333]
		pshs	pc,u,y,x,dp,a,b,cc
		puls	pc,u,y,x,dp,a,b,cc
		pshu	pc,s,y,x,dp,a,b,cc
		pulu	pc,s,y,x,dp,a,b,cc
		fcb	$38
		rts
		abx
		rti
		cwai	#$3C
		mul
		fcb	$3E
		swi

	; $40-4F
		nega
		fcb	$41
		fcb	$42
		coma
		lsra
		fcb	$45
		rora
		asra
		lsla
		rola
		deca
		fcb	$4B
		inca
		tsta
		fcb	$4E
		clra

	; $50-5F
		negb
		fcb	$51
		fcb	$52
		comb
		lsrb
		fcb	$55
		rorb
		asrb
		lslb
		rolb
		decb
		fcb	$5B
		incb
		tstb
		fcb	$5E
		clrb

	; $60-6F
		neg	-16,x
		fcb	$61
		fcb	$62
		com	15,x
		lsr	,x
		fcb	$65
		ror	,x++
		asr	,x+
		lsl	,-x
		rol	,--x
		dec	a,x
		fcb	$6B
		inc	<*+$6C+3,pc
		tst	>*+$6D8D+4,pc
		jmp	[<*+$6E+3,pc]
		clr	[>*+$6F9D+4,pc]

	; $70-7F
		neg	$7070
		fcb	$71
		fcb	$72
		com	$7373
		lsr	$7474
		fcb	$75
		ror	$7676
		asr	$7777
		lsl	$7878
		rol	$7979
		dec	$7A7A
		fcb	$7B
		inc	$7C7C
		tst	$7D7D
		jmp	$7E7E
		clr	$7F7F

	; $80-8F
		suba	#$80
		cmpa	#$81
		sbca	#$82
		subd	#$8383
		anda	#$84
		bita	#$85
		lda	#$86
		fcb	$87
		eora	#$88
		adca	#$89
		ora	#$8A
		adda	#$8B
		cmpx	#$8C8C
		bsr	* + 2 - 115
		ldx	#$8E8E
		fcb	$8F

	; $90-9F
		suba	$90
		cmpa	$91
		sbca	$92
		subd	$93
		anda	$94
		bita	$95
		lda	$96
		sta	$97
		eora	$98
		adca	$99
		ora	$9A
		adda	$9B
		cmpx	$9C
		jsr	$9D
		ldx	$9E
		stx	$9F

	; $A0-AF
		suba	,y+
		cmpa	,y++
		sbca	,-y
		subd	,--y
		anda	,y
		bita	b,y
		lda	a,y
		sta	,x
		eora	-88,y
		adca	$A9A9,y
		ora	,y
		adda	d,y
		cmpx	*-81,pc
		jsr	*-80,pc
		ldx	,y
		stx	[$AFAF]

	; $B0-$BF
		suba	$B0B0
		cmpa	$B1B1
		sbca	$B2B2
		subd	$B3B3
		anda	$B4B4
		bita	$B5B5
		lda	$B6B6
		sta	$B7B7
		eora	$B8B8
		adca	$B9B9
		ora	$BABA
		adda	$BBBB
		cmpx	$BCBC
		jsr	$BDBD
		ldx	$BEBE
		stx	$BFBF

	; $C0-CF
		subb	#$C0
		cmpb	#$C1
		sbcb	#$C2
		addd	#$C3C3
		andb	#$C4
		bitb	#$C5
		ldb	#$C6
		fcb	$C7
		eorb	#$C8
		adcb	#$C9
		orb	#$CA
		addb	#$CB
		ldd	#$CCCC
		fcb	$CD
		ldu	#$CECE
		fcb	$CF

	; $D0-DF
		subb	$D0
		cmpb	$D1
		sbcb	$D2
		addd	$D3
		andb	$D4
		bitb	$D5
		ldb	$D6
		stb	$D7
		eorb	$D8
		adcb	$D9
		orb	$DA
		addb	$DB
		ldd	$DC
		std	$DD
		ldu	$DE
		stu	$DF

	; $E0-EF
		subb	,s+
		cmpb	,s++
		sbcb	,-s
		addd	,--s
		andb	,s
		bitb	b,s
		ldb	a,s
		stb	,s
		eorb	-24,s
		adcb	$E9E9,s
		orb	,s
		addb	d,s
		ldd	*-17,pc
		std	*-16,pc
		ldu	,s
		stu	[$EFEF]

	; $F0-$FF
		subb	$F0F0
		cmpb	$F1F1
		sbcb	$F2F2
		addd	$F3F3
		andb	$F4F4
		bitb	$F5F5
		ldb	$F6F6
		stb	$F7F7
		eorb	$F8F8
		adcb	$F9F9
		orb	$FAFA
		addb	$FBFB
		ldd	$FCFC
		std	$FDFD
		ldu	$FEFE
		stu	$FFFF

		fcb	$60,$87	; neg illegal,x
		fcb	$60,$97 ; neg [illegal,x]
		fcb	$60,$8A	; neg illegal,x
		fcb	$60,$9A ; neg [illegal,x]
		fcb	$60,$8E ; neg illegal,x
		fcb	$60,$9E	; neg [illegal,x]
		fcb	$60,$FF,$60,$60

		nop
