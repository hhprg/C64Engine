/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Camera

//

.segment Zeropage "Camera zeropage data"

// Sprites with world x <= sprite cull should be culled.
zpMinSpriteCullLo:
.fill 1,0
zpMinSpriteCullHi:
.fill 1,0

// Sprites with world x >= sprite cull should be culled.
zpMaxSpriteCullLo:
.fill 1,0
zpMaxSpriteCullHi:
.fill 1,0

// Add this to a world position to get corresponding screen position.
zpWorldToScreenPositionXLo:
.fill 1,0
zpWorldToScreenPositionXHi:
.fill 1,0

//

.segment Code "Camera code"

.label kSpriteCullMin = -kSpriteWidth
.label kSpriteCullMax = kNumVisibleScreenPixels

.macro @CameraPostUpdate()
{
                lda Camera.PositionXLo         
                clc
                adc #<kSpriteCullMin
                sta Camera.zpMinSpriteCullLo
                lda Camera.PositionXHi
                adc #>kSpriteCullMin
                bpl SetHi
                lda #0 // Clamp to 0 if negative.
                sta Camera.zpMinSpriteCullLo
    SetHi:      sta Camera.zpMinSpriteCullHi
            
                lda Camera.PositionXLo         
                clc
                adc #<kSpriteCullMax
                sta Camera.zpMaxSpriteCullLo
                lda Camera.PositionXHi
                adc #>kSpriteCullMax
                sta Camera.zpMaxSpriteCullHi

                lda #<kSpriteStartX
                sec
                sbc Camera.PositionXLo
                sta Camera.zpWorldToScreenPositionXLo
                lda #>kSpriteStartX
                sbc Camera.PositionXHi
                sta Camera.zpWorldToScreenPositionXHi
}

.enum { kScrollRight=kRight, kScrollStopped=kNone, kScrollLeft=kLeft } // Don't change order!

.const kPositionOffset = kNumVisibleScreenPixels / 2
.const kWindowSize = 24 // < 128   

// Todo: Remove FineScroll and base everything on PositionX?

// Note: Scroll left/right refers to shifting screen columns left/right.

Init:
{
                ldx.zp LevelData.zpCurrent
                lda LevelData.StartPosLo,x               
                sta PositionXLo
                lda LevelData.StartPosHi,x               
                sta PositionXHi
                lda LevelData.MaxPosLo,x
                sta Update.LevelMaxPosLo
                lda LevelData.MaxPosHi,x
                sta Update.LevelMaxPosHi
                
                // Start stopped.
                lda #kScrollStopped
                sta ScrollDirection
                sta CanUndoShiftLeft               
                
                // Fine scroll all the way to the right, i.e. first screen column is fully visible.
                lda #7
                sta FineScroll
                bne UpdatePositionDiv2 // bra
}

//

GetDirection:
{           
                lda #kScrollStopped
                ldx PositionXHi
                cpx IdealPositionXHi
                bcc ScrollLeft
                bne ScrollRight
                ldx PositionXLo
                cpx IdealPositionXLo
                bcc ScrollLeft
                beq Done
    ScrollRight:lda #kScrollRight
                rts
    ScrollLeft: lda #kScrollLeft
    Done:       rts
}

//

UpdatePositionDiv2:
{
                lda PositionXLo
                sta PositionXDiv2Lo
                lda PositionXHi
                lsr
                ror PositionXDiv2Lo
                sta PositionXDiv2Hi
                rts                   
}

//

IncreasePosition:   
{
                // Increase position (in pixels).
                inc PositionXLo
                bne UpdatePositionDiv2
                inc PositionXHi
                bne UpdatePositionDiv2 // bra
}

//

DecreasePosition:
{
                // Decrease position (in pixels).
                lda #$ff
                dcp PositionXLo
                bne UpdatePositionDiv2
                dec PositionXHi
                jmp UpdatePositionDiv2
}  

//

Update:
{
                // Update ideal position of left side of screen
                // to keep player at center of screen.
                lda Player.PositionLo
                sec
                sbc #<kPositionOffset
                tax
                lda Player.PositionHi
                sbc #>kPositionOffset
                tay
                bpl NotMin
    ClampMin:   ldx #0
                ldy #0
                beq Valid // bra
    NotMin:     cmp LevelMaxPosHi:#0
                bcc Valid
                bne ClampMax
                cpx LevelMaxPosLo:#0
                bcc Valid
    ClampMax:   ldx LevelMaxPosLo
                ldy LevelMaxPosHi

    Valid:      // Keep camera moving to ideal position if already moving.
                lda ScrollDirection
                bne Set
       
                // Camera not moving, allow player movement within window.
                cpy IdealPositionXHi
                bcc Side
                bne Side
                cpx IdealPositionXLo
    Side:       php // c = 0 if position less than ideal position.
                txa
                sec
                sbc IdealPositionXLo
                plp
                bcs Positive
                eor #$ff // Negate to get abs of delta.
                adc #1
    Positive:   cmp #kWindowSize
                bcc Stay

    Set:        sty IdealPositionXHi                
                txa         
                and #$f8 // Lowest 3 bits are zero, i.e. fine scroll is 7 at ideal position.
                sta IdealPositionXLo         
    
    Stay:       lda ScrollDirection
                bmi ScrollingRight
                bne ScrollingLeft
            
                // Stopped.
                jsr GetDirection
                tax
                beq Done
                cmp #kScrollLeft
                beq StartScrollLeftFromStopped               
                bne StartScrollingRightFromStopped // bra
    Done:       rts
   
    //

    ScrollingRight:               
                lda FineScroll         
                cmp #7
                beq ScrollRightDone
            
                // Keep fine scrolling right.
                inc FineScroll
                bne DecreasePosition // bra
            
    ScrollRightDone:               
                lda CanUndoShiftLeft                                             
                beq FinishedFineScrollRight
            
    UndoShiftLeft:               
                lda #0         
                sta CanUndoShiftLeft
   
                // Was scrolling left, switch to back buffer which is already shifted one column right.
                jsr Scroll.UndoShiftLeft
                jmp ResumeScrollingRight
            
    FinishedFineScrollRight:     
                // Wait for scroll task to finish shifting screen one column right.          
                lda Scroll.IsShiftDone
                beq Done
            
                // Back buffer contains screen shifted one column right when we get here.
                jsr GetDirection
                tax
                beq StopScroll
                cmp #kScrollLeft
                beq StartScrollLeft
            
    ContinueScrollingRight:               
                // Back buffer contains screen shifted one column right, just flip buffers.         
                jsr Scroll.FinishShift
            
                // Resume scrolling right after shifting screen one column right.
    ResumeScrollingRight:               
                lda #0 // Fine scroll snaps from 7 to 0 here after shifting screen one column right.
                sta FineScroll
                jsr DecreasePosition
                jmp RequestShift
            
    //

    StartScrollingRightFromStopped:               
                lda #kScrollRight
                sta ScrollDirection
                
                lda CanUndoShiftLeft
                beq ContinueScrollingRight
                bne UndoShiftLeft // bra
        
    //

    StartScrollLeft:               
    StartScrollLeftFromStopped:               
                // Start scrolling left.
                lda #kScrollLeft
                sta ScrollDirection
                jsr RequestShift

    ScrollingLeft:               
                lda FineScroll
                beq ScrollLeftDone

                // Keep scrolling left.
                dec FineScroll
                jmp IncreasePosition
            
    ScrollLeftDone:               
                // Wait for scroll task to finish shifting screen one column left.          
                lda Scroll.IsShiftDone               
                beq Done
            
                // Back buffer contains screen shifted one column left when we get here, just flip buffers.
                jsr Scroll.FinishShift

                lda #7 // Fine scroll snaps from 0 to 7 here after shifting screen one column left.
                sta FineScroll
                jsr IncreasePosition

                // Indicate that screen was shifted left last which can be undone to shift right.
                lda #1
                sta CanUndoShiftLeft

                jsr GetDirection
                tax
                beq StopScroll
                cmp #kScrollRight
                beq StartScrollRight

                // Continue scrolling left.
                bne RequestShift // bra
            
    StopScroll: // Stop scroll, fine scroll is at 7 and back buffer contains screen shifted one column right          
                lda #kScrollStopped
                beq SetScrollDirection // bra
            
    StartScrollRight:               
                // Start scrolling right.         
                lda #kScrollRight
            
    SetScrollDirection:               
                sta ScrollDirection
                rts
}     

//

RequestShift:
{               
                lda ScrollDirection               
                jmp Scroll.RequestShift
}

//

.segment BSS2 "Camera data"

PositionXLo:
.fill 1, 0
PositionXHi:
.fill 1, 0

PositionXDiv2Lo:
.fill 1, 0
PositionXDiv2Hi:
.fill 1, 0

IdealPositionXLo:
.fill 1, 0
IdealPositionXHi:
.fill 1, 0

// 1 = left, 0 = stopped, -1 = right
ScrollDirection:
.fill 1, 0

// 0-7, where 7 is max fine scroll to right.
FineScroll:
.fill 1, 0

// 1 = true, 0 = false
// True means that back buffer is ready and we're not waiting for scroll task to finish.
// It means that we last shifted left, i.e. back buffer = front buffer shifted right.
CanUndoShiftLeft:
.fill 1, 0
