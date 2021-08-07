/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace SpriteClipAnimator

//

.segment Zeropage "SpriteClipAnimator zeropage data"

zpDstFramesLo:
.fill 1, 0
zpDstFramesHi:
.fill 1, 0

zpSrcFramesLo:
.fill 1, 0
zpSrcFramesHi:
.fill 1, 0

zpBase:
.fill 1, 0

//

.segment Code "SpriteClipAnimator code"
   
.label kNumCachedFrames = 32    // Number of cached sprite animation clip frames, must be power of 2, <= 128.
.label kNumSharedSlots = 4      // Number of slots of clip playback data.
.const kNumSlots = 4            //
.const kTotalNumSlots = kNumSharedSlots + kNumSlots
.const kNumBuffers = kNumSharedSlots // First kNumSharedSlots slots use buffers.

.macro @PlaySpriteClipSlot(spriteClipName, animatorSlot)
{
    .var clip = SpriteClipByName.get(spriteClipName)

                lda #SpriteClipKeysIndexByName.get(clip.clipKeysName)
                ldx #animatorSlot
                ldy #kSpriteBaseFrame + clip.base
                jsr SpriteClipAnimator.Play
                lda #clip.color
}

.macro @PlaySpriteClip(spriteClipName)
{
    .var clip = SpriteClipByName.get(spriteClipName)

                lda #SpriteClipKeysIndexByName.get(clip.clipKeysName)
                ldy #kSpriteBaseFrame + clip.base
                jsr SpriteClipAnimator.Play
}

.macro @SpriteClipAnimatorPreUpdate()
{
                // Save off used zeropage variables to make Update code re-entrant.
                // This is necessary because Update is called from background task
                // when initializing sprite frame ring-buffer, but is also called every frame
                // from main task.
                lda SpriteClipAnimator.zpSrcFramesLo
                pha
                lda SpriteClipAnimator.zpSrcFramesHi
                pha
                lda SpriteClipAnimator.zpDstFramesLo
                pha
                lda SpriteClipAnimator.zpDstFramesHi
                pha
}

.macro @SpriteClipAnimatorPostUpdate()
{
                // Restore used zeropage variables.
                pla
                sta SpriteClipAnimator.zpDstFramesHi
                pla
                sta SpriteClipAnimator.zpDstFramesLo
                pla
                sta SpriteClipAnimator.zpSrcFramesHi
                pla
                sta SpriteClipAnimator.zpSrcFramesLo
}

//

// Todo: Macro?
Init:
{
                ldx #kTotalNumSlots
                lda #0
    Clear:      dex
                sta ReferenceCounts,x
                bne Clear
                rts
}

//

// Must only be called by background task.
AllocSlot:
{
                ldx #kTotalNumSlots
    Try:        dex
                lda ReferenceCounts,x                           
                beq NewSlot
                cpx #kNumSharedSlots
                bne Try
                DebugHang() // Should never get here.
    NewSlot:    rts
}

//

Play:   
{
                // a = sprite clip index.
                // y = sprite frame offset.
                // c = 1 -> looping.
                // x = slot index.

                jsr InitSlot
                jsr Update.NewFrame
    Activate:   inc ReferenceCounts,x // Update reference count last since it's used by Update that runs on main task.
                rts
}

//

.label Activate = Play.Activate

//

// Must only be called by background task, it's not re-entrant!
PlayShared:      
{
                // a = sprite clip index.
                // y = sprite frame offset.
                sty Base
                ldx #kNumSlots - 1 // Shared uses first kNumSlots.
    Try:        ldy ReferenceCounts,x
                beq Skip
                cmp ClipIndices,x               
                bne Skip
                ldy BaseFrames,x
                cpy Base:#0
                beq Found
    Skip:       dex
                bpl Try

                // Didn't find slot playing sprite clip, allocate new slot.
                ldx #kNumSlots - 1
    TryAlloc:   ldy ReferenceCounts,x
                beq NewSlot
                dex
                bpl TryAlloc
                DebugHang() // Should never get here.

    NewSlot:    ldy Base

    // Can be called directly given a slot index (this part is re-entrant).
    Direct:     sec // c = 1: Always looping.
                jsr InitSlot

// Disable ring-buffer usage for now.
/*
                txa
                sta Buffers,x
                lda #-1
                sta BufferIndices,x

                // Fill ring buffer.
                lda #kNumCachedFrames
    Fill:       pha
                jsr Update.Active
                pla
                sec
                sbc #1
                bne Fill
*/
    Found:      // Found slot containing sprite clip, increase reference count.
                inc ReferenceCounts,x // Update reference count last since it's used by Update that runs on main task.
                rts          
}

//

InitSlot:
{
                // a = sprite clip index.
                // y = sprite frame offset.
                // c = 1: Looping.

                sta ClipIndices,x
                tya
                sta BaseFrames,x
                lda #1
                sta Playing,x
                sta Repeats,x
                lda #-1
                sta FrameIndices,x
                sta Buffers,x // Default to no buffer.
                lda #0
                rol
                sta Looping,x
                rts
}

//

// May be called by main and background task.
Deactivate:
{           
                // x = slot index.
                dec ReferenceCounts,x // Update reference count last since it's used by Update that runs on main task.
                rts
}

//

Update:   
{
                ldx #kTotalNumSlots - 1
    Next:       lda ReferenceCounts,x
                beq Skip
                lda Playing,x
                beq Skip
                jsr Active
    Skip:       dex
                bpl Next
                rts
            
    Active:     dec Repeats,x               
                bne SetFrame // Repeat previous frame.         
           
    NewFrame:   ldy ClipIndices,x
                lda SpriteClip.ClipKeysLo,y         
                sta zpSrcFramesLo
                lda SpriteClip.ClipKeysHi,y         
                sta zpSrcFramesHi
                ldy #1 // kHoldTime in header.
                lda (zpSrcFramesLo),y
                sta Repeats,x
                
                ldy FrameIndices,x
                iny
                tya
                ldy #0 // kLen in header.
                cmp (zpSrcFramesLo),y
                bcc NoWrap

                // Stop if one-shot animation.
                lda Looping,x               
                beq Stop
                
                lda #0 // Wrap.
                clc
    NoWrap:     sta FrameIndices,x                        
                adc #SpriteClip.kClipKeysHeaderSize // c = 0
                tay                
                lda (zpSrcFramesLo),y
                adc BaseFrames,x // c = 0
                sta CurrentFrames,x
   
    SetFrame:   ldy Buffers,x
                bmi Done
            
                // Add new frame to ring buffer.
                lda FramesLo,y
                sta zpDstFramesLo
                lda FramesHi,y
                sta zpDstFramesHi
                lda BufferIndices,x
                clc
                adc #1
                and #(kNumCachedFrames - 1) // Wrap
                sta BufferIndices,x
                tay               
                lda CurrentFrames,x               
                sta (zpDstFramesLo),y               
    Done:       rts               
            
    Stop:       dec Playing,x
                rts
}

//

.segment Code "SpriteClipAnimator const data"

FramesLo:   
.for (var i = 0; i < kNumBuffers; i++)
{
    .byte <(Frames + i * kNumCachedFrames)          
}

FramesHi:   
.for (var i = 0; i < kNumBuffers; i++)
{
    .byte >(Frames + i * kNumCachedFrames)          
}

//

.segment BSS2 "SpriteClipAnimator data"

// Frame ring-buffers.
Frames:   
.for (var i = 0; i < kNumBuffers; i++)
{
    .fill kNumCachedFrames, 0 // Sprite frames.          
}

// Current ring-buffer index for all ring-buffer slots.
BufferIndices:
.fill kNumBuffers, 0

// Ring-buffer used by clip.
Buffers:
.fill kNumSlots, 0

// First kNumSharedSlots are for shared playback.

// Current sprite frame for all clips.
CurrentFrames: 
.fill kTotalNumSlots, 0
  
// Current frame index in sprite clip frame array.
FrameIndices:
.fill kTotalNumSlots, 0

// Number of ticks left to repeat current frame.      
Repeats:
.fill kTotalNumSlots, 0
  
ClipIndices:
.fill kTotalNumSlots, 0

BaseFrames:
.fill kTotalNumSlots, 0

ReferenceCounts:
.fill kTotalNumSlots, 0

Playing:
.fill kTotalNumSlots, 0

Looping:
.fill kTotalNumSlots, 0
