/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Animator

//

.label kNumSlots = 3 // Number of slots of animator data.

.var ShowRasterTime = false

.macro @AnimatorPreUpdate()
{
                // Save off used zeropage variables to make Update code re-entrant.
                lda Animator.zpMegaSpriteDataLo
                pha
                lda Animator.zpMegaSpriteDataHi
                pha
}

.macro @AnimatorPostUpdate()
{
                // Restore saved off used zeropage variables to make Update code re-entrant.
                pla
                sta Animator.zpMegaSpriteDataHi
                pla
                sta Animator.zpMegaSpriteDataLo
}

//

.segment Zeropage "Animator zeropage data"

// Background task zeropage variables here.
zpSlot:         
.fill 1, 0

zpType:
.fill 1, 0

.label zpAnimationInstanceLo = AnimationTrigger.zpAnimationInstanceLo
.label zpAnimationInstanceHi = AnimationTrigger.zpAnimationInstanceHi

zpAnimationLo:
.fill 1,0
zpAnimationHi:
.fill 1,0

zpSpriteClipLo:
.fill 1,0
zpSpriteClipHi:
.fill 1,0

// Main task zeropage variables here.
zpUpdateSlot:         
.fill 1, 0

zpPositionListLo:
.fill 1,0
zpPositionListHi:
.fill 1,0

.label zpMegaSpriteDataLo = zpPositionListLo
.label zpMegaSpriteDataHi = zpPositionListHi

zpOriginXLo:
.fill 1,0
zpOriginXHi:
.fill 1,0
zpOriginY:
.fill 1,0
zpMinX:
.fill 1,0
zpMaxX:
.fill 1,0
zpPointer:
.fill 1,0
zpColorLayer:
.fill 1,0

//

.segment Code "Animator code"

// Todo: Macro?
// Todo: Put all data that should be cleared per level in separate segment?
Init:
{
                ldx #kNumSlots
                lda #0
    Clear:      dex
                sta ReferenceCounts,x
                bne Clear
                sta IsPreparingAnimation
                rts
}

//

DecodeAnimation:
{
                // Allocate animator slot.
                ldx #kNumSlots - 1
    Try:        ldy ReferenceCounts,x               
                beq Found         
                dex
                bpl Try
                DebugHang() // Should never get here.
 
    Found:      stx zpSlot

                ldy #0 // kTypeAnimationIndexHi
                lda (zpAnimationInstanceLo),y
                lsr
                sta zpType
                lda (zpAnimationInstanceLo),y
                and #%00000001
                sta zpAnimationHi
                iny    // kAnimationIndexLo
                lda (zpAnimationInstanceLo),y
                sta zpAnimationLo
                iny    // kOriginXHiLayer
                lda (zpAnimationInstanceLo),y
                and #%00111111
                sta OriginsXHi,x
                lda (zpAnimationInstanceLo),y
                and #%11000000
                sta SpriteColorLayers,x
                asl
                rol
                rol
                sta Layers,x
                lda #%10000000 
                sec
                sbc SpriteColorLayers,x
                sta SpriteColorLayers,x // Keep (2 - layer) in bits 6-7 of color.
                iny    // kOriginXLo            
                lda (zpAnimationInstanceLo),y
                sta OriginsXLo,x
                iny    // kOriginY
                lda (zpAnimationInstanceLo),y
                sta OriginsY,x
                iny    // kInstanceData
                lda (zpAnimationInstanceLo),y
                sta InstanceData,x

                // Address of Animation data.
                ldy zpType
                ldx AnimationData.TypeSizes,y
                lda AnimationData.BaseAdrLo,y
                pha
                lda AnimationData.BaseAdrHi,y
                tay
                txa
                beq SetDefAdr
                clc
    Add:        pla
                adc zpAnimationLo
                pha
                tya
                adc zpAnimationHi
                tay
                dex
                bne Add

    SetDefAdr:  pla
                sta zpAnimationLo
                sty zpAnimationHi

                ldx zpSlot
                rts
}

//

ActivateShared:
{
                // zpAnimationInstanceLo/Hi contain animation instance address.
                jsr DecodeAnimation

                // Decode Animation.
                ldy #0 // kSpriteClipIndex
                lda (zpAnimationLo),y
                sta zpSpriteClipLo
                sty zpSpriteClipHi

                // Address of SpriteClip
                asl  // x3 = kClipSize
                rol zpSpriteClipHi
                adc zpSpriteClipLo
                sta zpSpriteClipLo
                tya
                adc zpSpriteClipHi
                sta zpSpriteClipHi
                lda zpSpriteClipLo
                adc #<SpriteClip.Clips
                sta zpSpriteClipLo
                lda zpSpriteClipHi
                adc #>SpriteClip.Clips
                sta zpSpriteClipHi

                // Decode SpriteClip data.
                ldy #0 // kClipIndex
                lda (zpSpriteClipLo),y
                pha               
                iny    // kColor
                lda (zpSpriteClipLo),y
                ora SpriteColorLayers,x
                sta SpriteColorLayers,x
                iny    // kBaseFrame
                lda (zpSpriteClipLo),y
                tay
                pla
                jsr PlaySharedSpriteClip

                // Allocate PositionClipAnimator.
                ldy #1 // kPositionClipIndex
                lda (zpAnimationLo),y
                pha
                ldy zpType
                lda InstanceData,x // Type specific instance data.
                and AnimationData.InstanceDataFlipXYMasks,y
                tay
                pla
                jmp PlaySharedPositionClip
}

//

PlaySharedSpriteClip:
{
                // a = sprite clip index.
                // y = sprite frame offset.

                // Entering criticial section where zeropage variables must not be changed by main task.
                inc IsPreparingAnimation

                // Allocate SpriteAnimator.
                jsr SpriteClipAnimator.PlayShared

                // Exiting criticial section.
                dec IsPreparingAnimation

                txa
                ldx zpSlot
                sta SpriteClipAnimators,x
                rts
}

//

PlaySharedPositionClip:
{
                // a = PositionClip index.
                // y = flip xy flags.

                // Entering criticial section where zeropage variables must not be changed by main task.
                inc IsPreparingAnimation

                jsr PositionClipAnimator.PlayShared

                // Exiting criticial section.
                dec IsPreparingAnimation

                txa
                ldx zpSlot
                sta PositionClipAnimators,x
                rts
}

// Activate is not re-entrant.
ActivateClip:
{
                // zpAnimationInstanceLo/Hi contain Animation address.

                jsr ActivateShared

                ldy #2 // kNumSprites
                lda (zpAnimationLo),y
                sta NumSprites,x
                iny    // kPosSpacing
                lda (zpAnimationLo),y
                sta PositionSpacings,x // Actually spacing - 1.

                // #sprites * spacing = #sprites * (spacing - 1) + #sprites
                ldy NumSprites,x
                tya
                clc
    Add:        adc PositionSpacings,x
                dey
                bne Add
                sta MaxPositionBufferIndexOffsets,x

                // Fall throug to ExitActivate.
}

//

ExitActivate:
{
                inc ReferenceCounts,x // Update reference count last!
                rts      
}

//

ActivateFixed:
{
                // zpAnimationInstanceLo/Hi contain Animation address.

                jsr ActivateShared

                ldy #2 // kPositionListIndex    
                lda (zpAnimationLo),y
                sta PositionListIndices,x
                tay
                lda PositionList.ListsEndLo,y
                sec
                sbc PositionList.ListsLo,y
                sta NumSprites,x // Actually #sprite x2.
                bne ExitActivate // bra
}

//

ActivateMegaSprite:
{
                // zpAnimationInstanceLo/Hi contain Animation address.
                jsr DecodeAnimation

                ldy #0
                lda (zpAnimationLo),y
                jsr InitMegaSprite

                ldy #1 // kPositionClipIndex
                lda (zpAnimationLo),y
                dey
                jsr PlaySharedPositionClip
                jmp ExitActivate
}

//

InitMegaSprite:
{
                // a = mega sprite index.
                sta MegaSpriteIndices,x
                tay
                lda MegaSprite.DataEndLo,y
                clc // Skip color byte.
                sbc MegaSprite.DataLo,y
                sta NumSprites,x // Actually #sprites x3.

                lda MegaSprite.DataLo,y
                sta zpMegaSpriteDataLo
                lda MegaSprite.DataHi,y
                sta zpMegaSpriteDataHi
                ldy #0 // kColor
                lda (zpMegaSpriteDataLo),y
                ora SpriteColorLayers,x
                sta SpriteColorLayers,x
                rts
}

//

DeactivateShared:
{
                // zpAnimationInstanceLo/Hi contain Animation address.

                // y = animator slot index.
                sty zpSlot
                ldx SpriteClipAnimators,y
                jsr SpriteClipAnimator.Deactivate
                ldy zpSlot
    FreePositionClip:   
                ldx PositionClipAnimators,y
                jsr PositionClipAnimator.Deactivate
                ldy zpSlot
    DecreaseReferenceCount:
                dcp ReferenceCounts,y // dec ,y
                rts
}           

//

DeactivateMegaSprite:
{
                // zpAnimationInstanceLo/Hi contain Animation address.

                // y = animator slot index.
                sty zpSlot
                jmp DeactivateShared.FreePositionClip
}

//

PrepareUpdateWithOriginClip:
{
                // y = animator slot index.

                // Get x and y offset of origin.
                ldx PositionClipAnimators,y
                lda PositionClipAnimator.PositionsXHi,x
                sta PositionsXHi
                sta PositionsYHi
                lda PositionClipAnimator.BufferIndices,x
                sec
                sbc InstanceData,y
                and #PositionClipAnimator.kNumCachedPositions - 1
                tax
    .label PositionsYHi = *+2               
                lda PositionClipAnimator.Positions + PositionClipAnimator.kNumCachedPositions,x
                pha
    .label PositionsXHi = *+2               
                lda PositionClipAnimator.Positions,x
                tax
                pla

                // Fall through to PrepareUpdate.
}

//

PrepareUpdate:
{
    .if (ShowRasterTime) inc $d020         

                // a = OriginY offset.
                // x = OriginX offset.
                // y = animator slot index.
                sty zpUpdateSlot

                clc
                adc OriginsY,y
                sta zpOriginY

                // Local position to screen position translation.
                txa
                adc OriginsXLo,y
                sta OriginXLo
                lda OriginsXHi,y
                adc #0
                sta OriginXHi

                lda OriginXLo:#0
                adc Camera.zpWorldToScreenPositionXLo
                sta zpOriginXLo
                lda OriginXHi:#0
                adc Camera.zpWorldToScreenPositionXHi
                sta zpOriginXHi

                // Init sprite screen culling. 
                lda Camera.zpMinSpriteCullLo
                sec
                sbc OriginXLo
                tax
                lda Camera.zpMinSpriteCullHi                              
                sbc OriginXHi
                beq MinCull
                ldx #0   // Never
                bcc MinCull                              
                dex      // Always
    MinCull:    stx zpMinX           
            
                lda Camera.zpMaxSpriteCullLo
                sec
                sbc OriginXLo
                tax
                lda Camera.zpMaxSpriteCullHi                              
                sbc OriginXHi
                beq MaxCull
                ldx #$ff // Never
                bcs MaxCull                              
                inx      // Always
    MaxCull:    stx zpMaxX           

                // x = sprite animator slot index.
                ldx SpriteClipAnimators,y
                lda SpriteClipAnimator.CurrentFrames,x
                sta zpPointer
                lda SpriteColorLayers,y
                sta zpColorLayer

                lda Multiplexer.NumVirSprites
                cmp #Multiplexer.kMaxVirSprites
                bcc DoUpdate
                pla // Skip update.
                pla
    DoUpdate:   rts
}

//

UpdateClip:
{
                // y = animator slot index.
                lda #0
                tax
                jsr PrepareUpdate

                lda PositionSpacings,y
                sta Spacing

                // Set vir sprite positions. 
                ldx PositionClipAnimators,y
                lda PositionClipAnimator.PositionsXHi,x
                sta PositionsXHi
                sta PositionsYHi

                lda PositionClipAnimator.BufferIndices,x
                sec
                sbc MaxPositionBufferIndexOffsets,y               
                and #PositionClipAnimator.kNumCachedPositions - 1
                sta EndPositionIndex

                ldy PositionClipAnimator.BufferIndices,x
                ldx Multiplexer.NumVirSprites

                // x = vir sprite index
                // y = position ring buffer index.
   
    NextPosition:    
    .label PositionsXHi = *+2               
                lda PositionClipAnimator.Positions,y
            
                cmp zpMinX
                bcc Next
                cmp zpMaxX
                bcc OnScreen
                clc
                bcc Next // bra
         
    OnScreen:   adc zpOriginXLo
                sta Multiplexer.VirSpritePosXLo,x
                lda #0         
                adc zpOriginXHi
                sta Multiplexer.VirSpritePosXHi,x
         
    .label PositionsYHi = *+2               
                lda PositionClipAnimator.Positions + PositionClipAnimator.kNumCachedPositions,y
                clc
                adc zpOriginY
                sta Multiplexer.zpVirSpritePosY,x

                lda zpPointer
                sta Multiplexer.VirSpritePointers,x
                lda zpColorLayer         
                sta Multiplexer.VirSpriteColorLayers,x
                inx                  
            
                cpx #Multiplexer.kMaxVirSprites // Todo: Optimize?
                beq Finished
            
    Next:       tya
                sbc Spacing:#0 // c = 0                     
                and #PositionClipAnimator.kNumCachedPositions - 1
                tay         
                cpy EndPositionIndex:#0
                bne NextPosition

    Finished:   // x = index of next available vir sprite.               
                txa
                sec
                sbc Multiplexer.NumVirSprites
                stx Multiplexer.NumVirSprites

                ldy zpUpdateSlot
                ldx Layers,y
                clc
                adc Multiplexer.NumVirSpritesPerLayer,x
                sta Multiplexer.NumVirSpritesPerLayer,x
                rts
}      

//

UpdateFixed:
{
                // y = animator slot index.
                jsr PrepareUpdateWithOriginClip

                // Set vir sprite positions.
                ldx PositionListIndices,y
                lda PositionList.ListsLo,x
                sta zpPositionListLo
                lda PositionList.ListsHi,x
                sta zpPositionListHi

                lda NumSprites,y
                tay
                dey
                ldx Multiplexer.NumVirSprites

                // x = vir sprite index
                // y = position list index.
   
    NextPosition:    
                lda (zpPositionListLo),y
                dey

                cmp zpMinX
                bcc Next
                cmp zpMaxX
                bcs Next

                adc zpOriginXLo
                sta Multiplexer.VirSpritePosXLo,x
                lda #0         
                adc zpOriginXHi
                sta Multiplexer.VirSpritePosXHi,x

                lda (zpPositionListLo),y
                clc
                adc zpOriginY
                sta Multiplexer.zpVirSpritePosY,x

                lda zpPointer
                sta Multiplexer.VirSpritePointers,x
                lda zpColorLayer         
                sta Multiplexer.VirSpriteColorLayers,x
                inx                  

                cpx #Multiplexer.kMaxVirSprites
                beq Finished

    Next:       dey
                bpl NextPosition

    Finished:   jmp UpdateClip.Finished
}      

//

UpdateMegaSprite:
{
                // y = animator slot index.
                jsr PrepareUpdateWithOriginClip

    AddSprites: // Set vir sprite positions.
                ldx MegaSpriteIndices,y
                lda MegaSprite.DataLo,x
                sta zpMegaSpriteDataLo
                lda MegaSprite.DataHi,x
                sta zpMegaSpriteDataHi

                lda NumSprites,y
                tay
                ldx Multiplexer.NumVirSprites

                // x = vir sprite index
                // y = mega sprite index.
   
    NextPosition:    
                lda (zpMegaSpriteDataLo),y

                cmp zpMinX
                bcc Skip
                cmp zpMaxX
                bcs Skip

                adc zpOriginXLo
                sta Multiplexer.VirSpritePosXLo,x
                lda #0         
                adc zpOriginXHi
                sta Multiplexer.VirSpritePosXHi,x
                dey

                lda (zpMegaSpriteDataLo),y
                clc
                adc zpOriginY
                sta Multiplexer.zpVirSpritePosY,x
                dey

                lda (zpMegaSpriteDataLo),y
                sta Multiplexer.VirSpritePointers,x
                lda zpColorLayer // Todo: Per-sprite color?     
                sta Multiplexer.VirSpriteColorLayers,x
                inx                  

                cpx #Multiplexer.kMaxVirSprites
                beq Finished

                dey
                bne NextPosition
    Finished:   jmp UpdateClip.Finished

    Skip:       dey
                dey
                dey
                bne NextPosition
                jmp UpdateClip.Finished                
}      

//

AddSprite:
{
                ldx Multiplexer.NumVirSprites
                cpx #Multiplexer.kMaxVirSprites
                bcs Done

                ldy #3
                lda (zpMegaSpriteDataLo),y

                cmp zpMinX
                bcc Done
                cmp zpMaxX
                bcs Done

                adc zpOriginXLo
                sta Multiplexer.VirSpritePosXLo,x
                lda #0         
                adc zpOriginXHi
                sta Multiplexer.VirSpritePosXHi,x
                dey

                lda (zpMegaSpriteDataLo),y
                clc
                adc zpOriginY
                sta Multiplexer.zpVirSpritePosY,x
                dey

                lda (zpMegaSpriteDataLo),y
                sta Multiplexer.VirSpritePointers,x
                dey

                lda zpColorLayer
                and #$f0
                ora (zpMegaSpriteDataLo),y
                sta Multiplexer.VirSpriteColorLayers,x

                inc Multiplexer.NumVirSprites
                ldy zpSlot
                ldx Animator.Layers,y
                inc Multiplexer.NumVirSpritesPerLayer,x
    Done:       rts
}

//

.segment BSS2 "Animator data"

ReferenceCounts: // 0 or 1.
.fill kNumSlots, 0

PositionClipAnimators:
.fill kNumSlots, 0

SpriteClipAnimators:
.fill kNumSlots, 0

OriginsXLo:
.fill kNumSlots, 0

OriginsXHi:
.fill kNumSlots, 0

OriginsY:
.fill kNumSlots, 0

PositionSpacings:
.fill kNumSlots, 0

NumSprites:
.fill kNumSlots, 0

SpriteColorLayers:
.fill kNumSlots, 0

Layers:
.fill kNumSlots, 0

InstanceData:
.fill kNumSlots, 0

// #sprites * position spacing
MaxPositionBufferIndexOffsets:
.fill kNumSlots, 0

// For FixedAnimation that has a PositionList.
PositionListIndices:
.fill kNumSlots, 0

MegaSpriteIndices:
.fill kNumSlots, 0

// True when preparing/initializing/activating Animation on background task.
// In this case main task needs to save off some zeropage variables to avoid trashing them.
IsPreparingAnimation:
.byte 0
