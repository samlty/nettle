C nettle, low-level cryptographics library
C 
C Copyright (C) 2012 Niels Möller
C  
C The nettle library is free software; you can redistribute it and/or modify
C it under the terms of the GNU Lesser General Public License as published by
C the Free Software Foundation; either version 2.1 of the License, or (at your
C option) any later version.
C 
C The nettle library is distributed in the hope that it will be useful, but
C WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
C or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
C License for more details.
C 
C You should have received a copy of the GNU Lesser General Public License
C along with the nettle library; see the file COPYING.LIB.  If not, write to
C the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
C MA 02111-1307, USA.

define(<CTX>, <%rdi>)
define(<LENGTH>, <%rsi>)
define(<DST>, <%rdx>)
define(<SRC>, <%rcx>)
define(<T64>, <%r8>)
define(<POS>, <%r9>)
define(<X0>, <%xmm0>)
define(<X1>, <%xmm1>)
define(<X2>, <%xmm2>)
define(<X3>, <%xmm3>)
define(<T0>, <%xmm4>)
define(<T1>, <%xmm5>)
define(<M0101>, <%xmm6>)
define(<M0110>, <%xmm7>)
define(<M0011>, <%xmm8>)
define(<COUNT>, <%rax>)

C Possible improvements:
C 
C Do two blocks (or more) at a time in parallel, to avoid limitations
C due to data dependencies.
C 
C Avoid redoing the permutation of the input for each block (all but
C the two counter words are constant). Could also keep the input in
C registers.

C QROUND(x0, x1, x2, x3)
define(<QROUND>, <
	movaps	$4, T0		C 0
	paddd	$1, T0		C 1
	movaps	T0, T1		C 2
	pslld	<$>7, T0	C 2
	psrld	<$>25, T1	C 3
	pxor	T0, $2		C 3
	pxor	T1, $2		C 4

	movaps	$1, T0		C 0
	paddd	$2, T0		C 5
	movaps	T0, T1		C 6
	pslld	<$>9, T0	C 6
	psrld	<$>23, T1	C 7
	pxor	T0, $3		C 7
	pxor	T1, $3		C 8

	movaps	$2, T0		C 0
	paddd	$3, T0		C 9
	movaps	T0, T1		C 10
	pslld	<$>13, T0	C 10
	psrld	<$>19, T1	C 11
	pxor	T0, $4		C 11
	pxor	T1, $4		C 12

	movaps	$3, T0		C 0
	paddd	$4, T0		C 13
	movaps	T0, T1		C 14
	pslld	<$>18, T0	C 14
	psrld	<$>14, T1	C 15
	pxor	T0, $1		C 15
	pxor	T1, $1		C 16
>)

C SWAP(x0, x1, mask)
C Swaps bits in x0 and x1, with bits selected by the mask
define(<SWAP>, <
	movaps	$1, T0
	pxor	$2, $1
	pand	$3, $1
	pxor	$1, $2
	pxor	T0, $1
>)

	.file "salsa20.asm"
	
	C salsa20_crypt(struct salsa20_ctx *ctx, unsigned length,
	C		uint8_t *dst, const uint8_t *src)
	.text
	ALIGN(4)
PROLOGUE(nettle_salsa20_crypt)
	W64_ENTRY(4, 9)	

	test	LENGTH, LENGTH
	jz	.Lend

	C Load mask registers
	mov	$-1, XREG(COUNT)
	movd	XREG(COUNT), M0101
	pshufd	$0x09, M0101, M0011	C 01 01 00 00
	pshufd	$0x41, M0101, M0110	C 01 00 00 01
	pshufd	$0x22, M0101, M0101	C 01 00 01 00
	
.Lblock_loop:
	movups	(CTX), X0
	movups	16(CTX), X1
	movups	32(CTX), X2
	movups	48(CTX), X3

	C On input, each xmm register is one row. We start with
	C
	C	 0  1  2  3
	C	 4  5  6  7
	C	 8  9 10 11
	C	12 13 14 15
	C
	C Diagrams are in little-endian order, with least significant word to
	C the left. We rotate the columns, to get instead
	C
	C	 0  5 10 15
	C	 4  9 14  3
	C	 8 13  2  7
	C	12  1  6 11
	C 
	C The original rows are now diagonals.
	SWAP(X0, X1, M0101)
	SWAP(X2, X3, M0101)
	SWAP(X1, X3, M0110)
	SWAP(X0, X2, M0011)	

	movl	$10, XREG(COUNT)
	ALIGN(4)
.Loop:
	QROUND(X0, X1, X2, X3)
	C For the row operations, we first rotate the rows, to get
	C	
	C	0 5 10 15
	C	3 4  9 14
	C	2 7  8 13
	C	1 6 11 12
	C 
	C Now the original rows are turned into into columns. (This
	C SIMD hack described in djb's papers).

	pshufd	$0x93, X1, X1	C	11 00 01 10 (least sign. left)
	pshufd	$0x4e, X2, X2	C	10 11 00 01
	pshufd	$0x39, X3, X3	C	01 10 11 00

	QROUND(X0, X3, X2, X1)

	C Inverse rotation of the rows
	pshufd	$0x39, X1, X1	C	01 10 11 00
	pshufd	$0x4e, X2, X2	C	10 11 00 01
	pshufd	$0x93, X3, X3	C	11 00 01 10

	decl	XREG(COUNT)
	jnz	.Loop

	SWAP(X0, X2, M0011)	
	SWAP(X1, X3, M0110)
	SWAP(X0, X1, M0101)
	SWAP(X2, X3, M0101)

	movups	(CTX), T0
	movups	16(CTX), T1
	paddd	T0, X0
	paddd	T1, X1
	movups	32(CTX), T0
	movups	48(CTX), T1
	paddd	T0, X2
	paddd	T1, X3

	C Increment block counter
	incq	32(CTX)

	cmp	$64, LENGTH
	jc	.Lfinal_xor

	movups	48(SRC), T1
	pxor	T1, X3
	movups	X3, 48(DST)
.Lxor3:
	movups	32(SRC), T0
	pxor	T0, X2
	movups	X2, 32(DST)
.Lxor2:
	movups	16(SRC), T1
	pxor	T1, X1
	movups	X1, 16(DST)
.Lxor1:
	movups	(SRC), T0	
	pxor	T0, X0
	movups	X0, (DST)

	lea	64(SRC), SRC
	lea	64(DST), DST
	sub	$64, LENGTH
	ja	.Lblock_loop
.Lend:
	W64_EXIT(4, 9)
	ret

.Lfinal_xor:
	cmp	$32, LENGTH
	jz	.Lxor2
	jc	.Llt32
	cmp	$48, LENGTH
	jz	.Lxor3
	jc	.Llt48
	movaps	X3, T0
	call	.Lpartial
	jmp	.Lxor3
.Llt48:
	movaps	X2, T0
	call	.Lpartial
	jmp	.Lxor2
.Llt32:
	cmp	$16, LENGTH
	jz	.Lxor1
	jc	.Llt16
	movaps	X1, T0
	call	.Lpartial
	jmp	.Lxor1
.Llt16:
	movaps	X0, T0
	call	.Lpartial
	jmp	.Lend

.Lpartial:
	mov	LENGTH, POS
	and	$-16, POS
	test	$8, LENGTH
	jz	.Llt8
	C This "movd" instruction should assemble to
	C 66 49 0f 7e e0          movq   %xmm4,%r8
	C Apparently, assemblers treat movd and movq (with the
	C arguments we use) in the same way, except for osx, which
	C barfs at movq.
	movd	T0, T64
	xor	(SRC, POS), T64
	mov	T64, (DST, POS)
	lea	8(POS), POS
	pshufd	$0xee, T0, T0		C 10 11 10 11
.Llt8:
	C And this is also really a movq.
	movd	T0, T64
	test	$4, LENGTH
	jz	.Llt4
	mov	XREG(T64), XREG(COUNT)
	xor	(SRC, POS), XREG(COUNT)
	mov	XREG(COUNT), (DST, POS)
	lea	4(POS), POS
	shr	$32, T64
.Llt4:
	test	$2, LENGTH
	jz	.Llt2
	mov	WREG(T64), WREG(COUNT)
	xor	(SRC, POS), WREG(COUNT)
	mov	WREG(COUNT), (DST, POS)
	lea	2(POS), POS
	shr	$16, XREG(T64)
.Llt2:
	test	$1, LENGTH
	jz	.Lpartial_done
	xor	(SRC, POS), LREG(T64)
	mov	LREG(T64), (DST, POS)
.Lpartial_done:
	ret

EPILOGUE(nettle_salsa20_crypt)
