/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace PositionClipAnimator

//

.label kNumCachedPositions = 128  // Number of cached position clip frames, don't change.
.const kNumSlots = 3 // Number of slots of animator data.
.const kNumBuffers = kNumSlots

//

.segment Zeropage "PositionClipAnimator zeropage data"

zpClipLo:
.fill 1, 0
zpClipHi:
.fill 1, 0

zpDstPositionsXLo:
.fill 1, 0
zpDstPositionsXHi:
.fill 1, 0

zpDstPositionsYLo:
.fill 1, 0
zpDstPositionsYHi:
.fill 1, 0

zpPositionXFrac:
.fill kNumSlots, 0

zpPositionX:
.fill kNumSlots, 0   

zpVelocityXFrac:   
.fill kNumSlots, 0

zpVelocityX:   
.fill kNumSlots, 0

zpPositionYFrac:
.fill kNumSlots, 0

zpPositionY:
.fill kNumSlots, 0   

zpVelocityYFrac:   
.fill kNumSlots, 0

zpVelocityY:   
.fill kNumSlots, 0

//

.segment Code "PositionClipAnimator code"

.macro @PositionClipAnimatorPreUpdate()
{
                // Save off used zeropage variables to make Update code re-entrant.
                // This is necessary because UpdatePosition is called from background task
                // when initializing position ring-buffer, but is also called every frame
                // from main task.
                lda PositionClipAnimator.zpClipLo
                pha
                lda PositionClipAnimator.zpClipHi
                pha
                lda PositionClipAnimator.zpDstPositionsXHi
                pha
}

.macro @PositionClipAnimatorPostUpdate()
{
                // Restore used zeropage variables.
                pla
                sta PositionClipAnimator.zpDstPositionsYHi
                sta PositionClipAnimator.zpDstPositionsXHi
                pla
                sta PositionClipAnimator.zpClipHi
                pla
                sta PositionClipAnimator.zpClipLo
}

//

// Todo: Macro?
Init:
{
                ldx #kNumSlots
                lda #0
    Clear:      dex
                sta ReferenceCounts - 1,x
                bne Clear

                lda #<Positions
                sta zpDstPositionsXLo
                lda #<(Positions + kNumCachedPositions)
                sta zpDstPositionsYLo
                rts
}

// PlayShared is not re-entrant!
PlayShared: 
{
                // a = PositionClip index.
                // y = flip xy flags.
                sty FlipXY
                ldx #kNumSlots - 1
    Try:        ldy ReferenceCounts,x
                beq Skip
                cmp ClipIndices,x               
                bne Skip
                ldy FlipXYs,x
                cpy FlipXY:#0
                beq Found // c = 1               
    Skip:       dex
                bpl Try

                // Allocate position clip animator.
                ldx #kNumSlots - 1
    TryAlloc:   ldy ReferenceCounts,x               
                beq NewSlot         
                dex
                bpl TryAlloc
                DebugHang() // Should never get here.
    
    NewSlot:    tay
                sta ClipIndices,x
                lda FlipXY
                sta FlipXYs,x
                lda #-1
                sta BufferIndices,x

                // x = animator slot index.
                // y = PositionClip index.

                // Init flip xy constants.
                lda PositionClip.ClipsLo,y
                sta zpClipLo
                lda PositionClip.ClipsHi,y
                sta zpClipHi
                ldy #2 // kFlipXConstant
                lda (zpClipLo),y
                asl
                sta FlipXConstants,x
                iny    // kFlipYConstant
                lda (zpClipLo),y
                asl
                sta FlipYConstants,x

                ldy ClipIndices,x
                jsr SetStartKeyframe

                // Fill ring buffer with positions.
                lda #kNumCachedPositions - 1
    Fill:       pha
                jsr UpdatePosition
                pla
                sec
                sbc #1
                bne Fill

    Found:      inc ReferenceCounts,x
                rts
}

//

// x = animator slot index.
Deactivate:
{
                dec ReferenceCounts,x
                rts
}           

//

Update:   
{
                ldx #kNumSlots - 1
    Try:        lda ReferenceCounts,x         
                beq Next         
                jsr UpdatePosition
    Next:       dex
                bpl Try
                rts
}

//

UpdatePosition:
{
                // x = animator slot index.
                clc
                lda zpPositionXFrac,x
                adc zpVelocityXFrac,x
                sta zpPositionXFrac,x
                lda zpPositionX,x
                adc zpVelocityX,x
                sta zpPositionX,x
                clc
                lda zpPositionYFrac,x
                adc zpVelocityYFrac,x
                sta zpPositionYFrac,x
                lda zpPositionY,x
                adc zpVelocityY,x
                sta zpPositionY,x
                dec Repeats,x
                beq NextKeyframe
    
    //

    AddPosition:lda PositionsXHi,x
                sta zpDstPositionsXHi
                sta zpDstPositionsYHi

                lda BufferIndices,x
                clc
                adc #1
                and #(kNumCachedPositions - 1) // Wrap
                sta BufferIndices,x
                tay

                lda FlipXYs,x
                and #%01000000
                bne FlipX
                lda zpPositionX,x               
                jmp AddPosX
    FlipX:      lda FlipXConstants,x
                sec
                sbc zpPositionX,x
    AddPosX:    sta (zpDstPositionsXLo),y

                lda FlipXYs,x
                bmi FlipY
                lda zpPositionY,x               
                jmp AddPosY
    FlipY:      lda FlipYConstants,x
                sec
                sbc zpPositionY,x
    AddPosY:    sta (zpDstPositionsYLo),y               
                rts

    //

    NextKeyframe:
   
                // x = animator slot index.
                lda ClipLo,x
                clc
                adc #PositionClip.kClipKeyframeSize
                sta ClipLo,x
                bcc NoHi
                inc ClipHi,x
    NoHi:       ldy ClipIndices,x
                cmp PositionClip.ClipsEndLo,y
                bne SetKeyframeData
                lda ClipHi,x
                cmp PositionClip.ClipsEndHi,y
                bne SetKeyframeData
            
    LoopClip:   // Set start keyframe (assumes looping clip).           
                // y = PositionClip index.
                lda PositionClip.ClipsLo,y
                sta zpClipLo
                clc
                adc #PositionClip.kClipHeaderSize
                sta ClipLo,x
                lda PositionClip.ClipsHi,y
                sta zpClipHi
                adc #0
                sta ClipHi,x

                lda #0
                sta zpPositionXFrac,x
                sta zpPositionYFrac,x

                tay // kStartX
                lda (zpClipLo),y
                sta zpPositionX,x
                iny // kStartY
                lda (zpClipLo),y
                sta zpPositionY,x
            
    SetKeyframeData:                   
                // Init keyframe data.
                lda ClipLo,x
                sta zpClipLo
                lda ClipHi,x
                sta zpClipHi

                lda #0
                sta zpVelocityX,x
                sta zpVelocityY,x

                tay // kDuration
                lda (zpClipLo),y
                sta Repeats,x
                
                // Decode velocity x.
                iny // kVelX
                lda (zpClipLo),y
                bpl VelX
                dec zpVelocityX,x // Sign-extend.
    VelX:       asl               
                rol zpVelocityX,x         
                asl
                rol zpVelocityX,x
                asl
                rol zpVelocityX,x
                sta zpVelocityXFrac,x
                
                // Decode velocity y.
                iny // kVelY
                lda (zpClipLo),y
                bpl VelY
                dec zpVelocityY,x
    VelY:       asl               
                rol zpVelocityY,x         
                asl
                rol zpVelocityY,x
                asl
                rol zpVelocityY,x
                sta zpVelocityYFrac,x
                jmp AddPosition               
}

.label SetStartKeyframe = UpdatePosition.LoopClip

//

.segment Code "PositionClipAnimator const data"

PositionsXHi:   
.for (var i = 0; i < kNumSlots; i++)
{
    .byte >(Positions + i * 2 * kNumCachedPositions)          
}

//

.segment BSS2 "PositionClipAnimator data"

// Current ring-buffer index for all slots.
BufferIndices:
.fill kNumBuffers, 0

// Position clip data for current keyframe.
ClipLo:
.fill kNumSlots, 0

ClipHi:
.fill kNumSlots, 0

// Number of ticks left to apply current velocity.      
Repeats:
.fill kNumSlots, 0

ClipIndices:
.fill kNumSlots, 0

FlipXYs:
.fill kNumSlots, 0

FlipXConstants:
.fill kNumSlots, 0

FlipYConstants:
.fill kNumSlots, 0

ReferenceCounts:
.fill kNumSlots, 0

.align 256 // Don't remove, alignment makes sure that PositionsXHi == PositionsYHi.

// Position ring-buffers.
Positions:   
.for (var i = 0; i < kNumBuffers; i++)
{
    .fill kNumCachedPositions, 0 // Position x frames.          
    .fill kNumCachedPositions, 0 // Position y frames.          
}
