* Wakestate detect v1.0 by Troed/SYNC
*
* As promised during my overscan and sync scroll talk at STNICCC 2015
* here's a piece of code to detect which wakestate the machine is
* currently in. It's done using a specially crafted scanline which
* due to the combination and position of GLUE frequency and resolution
* register changes creates a scanline of different length in ST 
* wakestate 1,2,3,4 as well as on STE.
*
* Feel free to include _detect_ws in your own code.
*
* More information on how this works here:
* http://www.atari-wiki.com/?title=ST_STE_Scanlines
*

* uncomment to compile to WSDETECT.BIN for writing to boot sector
*__BOOTSECTOR

* uncomment to only open right border - useful when aligning code 
*__ALIGN

	ifd __BOOTSECTOR
	output WSDETECT.BIN
	opt nodebug
	endc

_prg_base
	ifnd __BOOTSECTOR
	move.l 4(sp),a0		* base page
	move.l #$100,d0		* length of basepage
	add.l $c(a0),d0		* length of TEXT
	add.l $14(a0),d0	* length of DATA
	add.l $1c(a0),d0	* length of BSS
	
	move.l d0,-(sp)
	move.l a0,-(sp)
	clr.w -(sp)
	move.w #$4a,-(sp)	* mshrink
	trap #1
	lea 12(sp),sp

	pea 0
	move.w #$20,-(sp)
	trap #1
	addq.l #6,sp
	lea _ssp(pc),a0
	move.l d0,2(a0)
	endc

	lea _sres(pc),a0
	move.b $ffff8260.w,3(a0)
	lea _sfreq(pc),a0
	move.b $ffff820a.w,3(a0)

	lea _ssr(pc),a0
	move.w sr,2(a0)

	lea _svbl(pc),a0
	move.l $70.w,2(a0)
	move.w #$2300,sr
	lea _vbl(pc),a0
	move.l a0,$70.w

	lea _vsync(pc),a0
	sf (a0)
_vwait	tst.b (a0)
	beq.s _vwait

	bsr _detect_ws		* here be magic

	lea _vsync(pc),a0
	sf (a0)
_vwat2	tst.b (a0)
	beq.s _vwat2

_sres	move.b #0,$ffff8260.w
_sfreq	move.b #0,$ffff820a.w
	
_svbl	move.l #0,$70.w
_ssr	move.w #0,sr
	pea _info(pc)
	move.w #$9,-(sp)
	trap #1
	addq.l #6,sp

_exit
	ifnd __BOOTSECTOR
_ssp	move.l #0,-(sp)
	move.w #$20,-(sp)
	trap #1
	addq.l #6,sp

_exit2	move.w #0,-(sp)
	move.w #$4c,-(sp)	* p_term
	trap #1
	else
	rts
	endc

* assumes _vsync in a0
_vbl
	st (a0)
	rte

	even

_vsync	ds.w 1

* Must be run just after VBL - expects to lock onto first line.
*
* HI/LO back at cycle 4	 = left border (short) open on STE 
* 60/50 back at cycle 54 = 60Hz line start (+2) in WS1/WS3
* HI/LO at cycle 168	 = early (mono) screen end in WS2
* HI/LO at cycle 378	 = right border open in WS3/WS4/WS2
* = 180 byte line, STE
*    54 byte line, WS2
*   206 byte line, WS3
*   204 byte line, WS4
*   162 byte line, WS1

_detect_ws
	move.w #$2700,sr 
	movem.l d0-d7/a0-a1,-(sp)

	lea $ffff820a,a0
	lea $ffff8260,a1

	* run tests in low res & 50 hz
	move.b #0,(a1)
	move.b #2,(a0)

	* skip line
.l0	move.b $ffff8209.w,d0
	cmp.b $ffff8209.w,d0
	bne.s .l0

	* skip border, then lock
	moveq #0,d0
.sync	move.b $ffff8209.w,d0
	cmp.b $ffff8209.w,d0
	beq.s .sync
	move.b $ffff8209.w,d0
	not.w d0
	lsr.w d0,d0

	moveq #0,d0
	moveq #0,d2
	moveq #0,d3
	moveq #0,d4
	moveq #0,d5

*	dcb.w 64,$4e71
	moveq #20-1,d7	* 1+20*3+1 nop
.d1	dbf d7,.d1
	or.l d0,d0

	move.b $ffff8207.w,d2	* 3 nop
	move.b $ffff8209.w,d3	* 3 nop

* cycle 508

	ifd __ALIGN

*	dcb.w 95,$4e71
	moveq #31-1,d7	* 1+31*3+1 nop
.d2	dbf d7,.d2

	else
	move.w a0,(a1)
* HI/LO back at cycle 4 will open a short left border on STE
	move.b d0,(a1)

*	dcb.w 7,$4e71
	moveq #1-1,d7	* 1+1*3+1 nop
.d2	dbf d7,.d2
	or.l d0,d0

	move.b d0,(a0)
	exg d0,d0
* cycle 54 - back to 50Hz will cause +2 in WS1/WS3 but not WS2/WS4
	move.w a0,(a0)

* cycle 64
*	dcb.w 26,$4e71
	moveq #8-1,d7	* 1+8*3+1 nop
.d3	dbf d7,.d3

* HI/LO at cycle 168 will cause screen stop in WS2
	move.w a0,(a1)
	move.b d0,(a1)

*	dcb.w 47,$4e71
	moveq #15-1,d7	* 1+15*3+1 nop
.d4	dbf d7,.d4
	exg d0,d0

* cycle 378 - right border RES WS2/WS3/WS4 position
	endc
	move.w a0,(a1)
	move.b d0,(a1)

*	dcb.w 23,$4e71
	moveq #7-1,d7	* 1+7*3+1 nop
.d5	dbf d7,.d5

* cycle 488 - safe to read video address

	move.b $ffff8207.w,d4	* 3 nop
	move.b $ffff8209.w,d5	* 3 nop

* cycle 0 - clear shifter using Level 16 stabilizer

	moveq #30-1,d7	* 1+30*3+1 nop
.d6	dbf d7,.d6
	or.l d0,d0

	move.b d0,(a0)
	move.w a0,(a0)

	moveq #3-1,d7	* 1+3*3+1 nop
.d7	dbf d7,.d7
	or.l d0,d0

	move.w a0,(a1)
	nop
	move.b d0,(a1)

* time to do math
* if d4d5-d2d3 == 54 then we're in WS2
* else if d4d5-d2d3 == 206 we're in WS3
* else if d4d5-d2d3 == 204 we're in WS4
* else if d4d5-d2d3 == 162 we're in WS1
* else if d4d5-d2d3 == 180 we're on STE
* else .. well should not happen

	lsl.w #8,d2
	or.b d3,d2
	lsl.w #8,d4
	or.b d5,d4

	sub.w d2,d4

	lea _ws(pc),a0
	cmp.w #54,d4
	beq.s .ws2
	cmp.w #206,d4
	beq.s .ws3
	cmp.w #204,d4
	beq.s .ws4
	cmp.w #162,d4
	beq.s .ws1
	cmp.w #180,d4
	beq.s .ste
.unknown
	* call me :P
	bra.s .done
.ws1	
	move.b #'1',3(a0)
	bra.s .done	
.ws2	
	move.b #'2',3(a0)
	bra.s .done	
.ws3	
	move.b #'3',3(a0)
	bra.s .done	
.ws4	
	move.b #'4',3(a0)
	bra.s .done	
.ste	
	move.l #' STE',(a0)
*	bra.s .done
.done
	movem.l (sp)+,a0-a1/d0-d7
	move.w #$2300,sr
	rts

	even
*	ds.b 1	* to align _ws on even boundary

_info	dc.b $d,$a,27,'p',' Wakestate detection v1.0 by Troed/SYNC ',27,'q',$d,$a 
_ws	dc.b ' WS? detected',$d,$a,0
