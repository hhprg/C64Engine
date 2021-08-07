/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Memory

//

.segment Zeropage "Memory zeropage data"

zpMemSetLo:
.fill 1, 0
zpMemSetHi:
.fill 1, 0

//

.segment Code "Memory code"

.const BSS1Size = BSS1End - BSS1Begin 
.const BSS2Size = BSS2End - BSS2Begin 
.const kClear = $00

Init:
{
                ldy #<(ZeropageEnd - ZeropageBegin)
                lda #kClear
    Clear:      dey
                sta ZeropageBegin,y
                bne Clear            
                
                ldy #0
                jsr ClearBSS
                ldy #1 // Fall through to Clear.
}

ClearBSS:
{     
                // y = BSS memory block index.
                lda BSSMemLo,y
                sta zpMemSetLo
                lda BSSMemHi,y
                sta zpMemSetHi
                lda BSSSizeLo,y
                pha
                ldx BSSSizeHi,y
                beq Lo
                lda #0
                jsr Clear
    Lo:         pla
                beq Done   
                inx
    Clear:      tay
                lda #kClear
    SetHi:      dey
                sta (zpMemSetLo),y               
                bne SetHi
                inc zpMemSetHi
                dex
                bne SetHi
    Done:       rts
}

.segment Code "Memory const data"

BSSMemLo:
.byte <BSS1Begin, <BSS2Begin

BSSMemHi:
.byte >BSS1Begin, >BSS2Begin

BSSSizeLo:
.byte <BSS1Size, <BSS2Size

BSSSizeHi:
.byte >BSS1Size, >BSS2Size
