* Writes WSDETECT.BIN to boot sector in drive A:

_prg_base
	bra main
	section text

main
	move.l 4(sp),a0		* base page
*	lea _stackend,sp

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

	pea _info
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp

	jsr _cache		* read bootsector into memory
	cmp.w #0,d0
	bge.s .cached

	* error on open
	pea _errmsg
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp

	move.w #7,-(sp)		* cin
	trap #1
	addq.l #2,sp

	bra _exit2
	
.cached	pea _cached
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp

_again
.exec	jsr _executable
	cmp.b #0,d0
	beq .notexec

	* boot sector already executable, warn

	pea _warn
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp

.notexec

	pea _ask
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp

	move.w #7,-(sp)		* cin
	trap #1
	addq.l #2,sp

	cmp.b #'y',d0
	bne.s _abort

	* if the disk was changed, re-check executable status
	move.w #0,-(sp)
	move.w #9,-(sp)
	trap #13
	addq.l #4,sp
	cmp.b #0,d0		* Getting a lot of false positives from

	bra.s .ok
*	beq.s .ok		* "may have been changed" (1)
				* But only checking for 2 misses a lot
				* of disk changes. Due to the HxC??

	pea _changed
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp
	
	bra .exec

.ok	pea _writing
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp

	pea _install
	move.w #38,-(sp)
	trap #14
	addq.l #6,sp

	pea _done
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp

_exit	move.w #7,-(sp)		* cin
	trap #1
	addq.l #2,sp
	cmp #'y',d0
	beq _again

_exit2	move.w #0,-(sp)
	move.w #$4c,-(sp)	* p_term
	trap #1

_abort
	pea _aborted
	move.w #$9,-(sp)	* print line
	trap #1
	addq.l #6,sp

	bra.s _exit

* Check if the boot sector is already executable
* return value in d0. 0 = not executable, 1 = executable
_executable
	move.w #1,-(sp)
	move.w #0,-(sp)
	move.w #0,-(sp)
	move.w #1,-(sp)
	move.w #0,-(sp)
	move.l #0,-(sp)
	move.l #_temp,-(sp)
	move.w #8,-(sp)
	trap #14
	lea 20(sp),sp

	move.w _temp+510,d7

	move.w #1,-(sp)
	move.w #-1,-(sp)
	move.l #-1,-(sp)
	move.l #_temp,-(sp)
	move.w #$12,-(sp)
	trap #14
	lea 14(sp),sp

	moveq #0,d0
	cmp.w _temp+510,d7
	bne.s .exit
	moveq #1,d0
.exit
	rts

* Loads WSDETECT.BIN from disk (and skips TOS .prg header)
* returns error value from f_open in d0
_cache
	move.w #0,-(sp)
	move.l #_fname,-(sp)
	move.w #$3d,-(sp)		* f_open
	trap #1
	addq.l #8,sp
	tst.w d0
	bmi.s _error
	move.w d0,_fhandle

	move.w #0,-(sp)			* f_seek
	move.w _fhandle,-(sp)
	move.l #28,-(sp)
	move.w #$42,-(sp)
	trap #1
	lea 10(sp),sp

	move.l #_sector+30,-(sp)
	move.l #480,-(sp)
	move.w _fhandle,-(sp)
	move.w #$3f,-(sp)		* f_read
	trap #1
	lea 12(sp),sp
	
	move.w _fhandle,-(sp)
	move.w #$3e,-(sp)
	trap #1
	addq.l #4,sp
_error	rts

**
* gemdos $19 - get current drive
* bios 7 - get device parameter block
* xbios 8 - read sectors
* xbios 9 - write sectors
* xbios $12 - build prototype boot sector
**
_install
	move.w #1,-(sp)
	move.w #0,-(sp)
	move.w #0,-(sp)
	move.w #1,-(sp)
	move.w #0,-(sp)
	move.l #0,-(sp)
	move.l #_temp,-(sp)
	move.w #8,-(sp)
	trap #14
	lea 20(sp),sp

	move.w #$601c,_temp		* bra to code
*	move.w #$4e75,_temp		* rts

	lea _sector+30,a0
	lea _temp+30,a1
	move.l #480/4-1,d0
.l1	move.l (a0)+,(a1)+
	dbf d0,.l1

	move.w #1,-(sp)
	move.w #-1,-(sp)
	move.l #-1,-(sp)
	move.l #_temp,-(sp)
	move.w #$12,-(sp)
	trap #14
	lea 14(sp),sp

	move.w #1,-(sp)
	move.w #0,-(sp)
	move.w #0,-(sp)
	move.w #1,-(sp)
	move.w #0,-(sp)
	move.l #0,-(sp)
	move.l #_temp,-(sp)
	move #9,-(sp)
	trap #14
	lea 20(sp),sp

	rts

	section data

_fname	dc.b 'WSDETECT.BIN',0

_info	
	dc.b 27,'E'
	dc.b ' This program is part of the Wakestate detection utility',$d,$a
	dc.b ' written by Troed/SYNC. It will write the file WSDETECT.BIN which',$d,$a
	dc.b ' should reside in the same directory to the boot sector of this',$d,$a
	dc.b ' or another disk in drive A:. You can also simply put WSDETECT.PRG',$d,$a
	dc.b ' in an AUTO folder if you do not want to use the boot sector.',$d,$a
	dc.b $d,$a,0

_cached	dc.b ' WSDETECT.BIN has now been cached in memory, feel free to switch disk.',$d,$a
	dc.b $d,$a,0

_ask	dc.b ' Write WSDETECT.BIN to bootsector in drive A:? (y/[n])',$d,$a
	dc.b $d,$a,0

_warn	dc.b ' ',27,'p',' WARNING ',27,'q',' The current boot sector is already executable. Make sure',$d,$a
	dc.b '           you know what you''re about to overwrite!',$d,$a
	dc.b $d,$a,0

_changed
	dc.b ' Disk change detected - rechecking ...',$d,$a
	dc.b $d,$a,0

_writing
	dc.b ' Writing bootsector ... ',0
_done	dc.b 'done. Press SPACE to exit or ''y'' to write another',$d,$a
	dc.b $d,$a,0

_aborted
	dc.b ' Aborted. Press SPACE to exit or ''y'' to write another',$d,$a
	dc.b $d,$a,0

_errmsg	dc.b ' WSDETECT.BIN could not be opened. Press any key to exit.',0
	
	even
	section bss

_fhandle ds.w 1
_sector	ds.b 512
_temp	ds.b 512

_prg_end

