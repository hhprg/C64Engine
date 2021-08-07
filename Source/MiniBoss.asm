/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

//

.struct MiniBossAnimation { name, positionClipName }
.eval AnimationTypes.add("MiniBossAnimation")
.eval AnimationTypeCallbacks.put("MiniBossAnimation", Callbacks(MiniBoss.Activate, MiniBoss.Deactivate, MiniBoss.Update))

.function GetMiniBossAnimationData(data, animation)
{
    .if (animation.getStructName() == "MiniBossAnimation")
    {
        .eval data.add(GetPositionClipIndexByName(animation.positionClipName))
    }

    .return data
}

.function GetMiniBossAnimationRange(rangeX, animation)
{
    .if (animation.getStructName() == "MiniBossAnimation")
    {
        .var positionClip = GetPositionClipByName(animation.positionClipName)
        .var clipRangeX = PositionClipRange(positionClip)
        .var megaSpriteRangeX = MegaSpriteRange(GetMegaSpriteByName("MiniBoss"))

        .eval rangeX.minX = clipRangeX.minX + megaSpriteRangeX.minX
        .eval rangeX.maxX = clipRangeX.maxX + megaSpriteRangeX.maxX
    }

    .return rangeX
}

//

.filenamespace MiniBoss

//

.const kMegaSpriteIndex = MegaSpriteIndexByName.get("MiniBoss")
.const kMegaSprite = AllMegaSprites.get(kMegaSpriteIndex)

.const kLocalBoundsX = MegaSpriteBoundsX(kMegaSprite).maxX + kSpriteWidth
.const kLocalBoundsY = MegaSpriteBoundsY(kMegaSprite).maxX + kSpriteHeight
.const kLocalOriginX = kLocalBoundsX / 2
.const kLocalOriginY = kLocalBoundsY / 2
.const kCannonY = kLocalOriginY

// States.
.enum { kClosed, kOpening, kShooting, kClosing }

//

.segment Code "MiniBoss code"

//

Activate:
{
                // zpAnimationLo/Hi contain Animation address.

                jsr Animator.DecodeAnimation

                lda #kClosed
                sta States,x
                lda #kMegaSpriteIndex
                jsr Animator.InitMegaSprite

                // Pre-allocate sprite animator slot.
                jsr SpriteClipAnimator.AllocSlot
                lda #0
                sta SpriteClipAnimator.Playing,x
                jsr SpriteClipAnimator.Activate
                txa
                ldx Animator.zpSlot
                sta Animator.SpriteClipAnimators,x

                ldy #0 // kPositionClipIndex
                lda (Animator.zpAnimationLo),y
                jsr Animator.PlaySharedPositionClip
                jmp Animator.ExitActivate
}

//

.label Deactivate = Animator.DeactivateShared

//

Update:
{
                // y = animator slot index.
                jsr Animator.UpdateMegaSprite

                lda States,y
                asl
                adc States,y
                sta Offset
                ldx Animator.SpriteClipAnimators,y
                lda SpriteClipAnimator.Playing,x
                bcc Offset:* // bra

                jmp Closed
                jmp Opening
                jmp ClosedFrame // Todo: Shooting
                jmp Closing

    //

    Opening:    bne UpdateFrame
                jsr SpriteClipAnimator.Deactivate
                PlaySpriteClip("MiniBossCloseCannon")
                lda #kClosing
                bpl SetState // bra

    //

    Closing:    bne UpdateFrame
                lda #kClosed
                sta States,y
    ClosedFrame:lda #155 + kSpriteBaseFrame
                bne SetFrame // bra   

    //

    Closed:     lda Animator.zpOriginY
                clc
                adc #kCannonY - kSpriteStartY
                sec
                sbc Player.PositionLo + 1
                bcs AbsDeltaY
                eor #$ff
                adc #1
    AbsDeltaY:  cmp #8
                bcs ClosedFrame

                // Only open if on left side of player.
                lda Animator.PrepareUpdate.OriginXHi
                cmp Player.PositionHi + 0
                bcc ClosedFrame
                bne Open
                lda Animator.PrepareUpdate.OriginXLo
                cmp Player.PositionLo + 0
                bcc ClosedFrame

    Open:       jsr SpriteClipAnimator.Deactivate
                clc
                PlaySpriteClip("MiniBossOpenCannon")
                lda #kOpening

    //

    SetState:   ldy Animator.zpUpdateSlot
                sta States,y

    UpdateFrame:lda SpriteClipAnimator.CurrentFrames,x
    SetFrame:   sta CannonData + 1

                lda #<CannonData
                sta Animator.zpMegaSpriteDataLo
                lda #>CannonData
                sta Animator.zpMegaSpriteDataHi
                jmp Animator.AddSprite
}

//

.segment Code "MiniBoss const data"

CannonData:
.byte 14, 155 + kSpriteBaseFrame, 21, 24

//               

.segment BSS2 "Animator data"

States:
.fill Animator.kNumSlots, 0

SpriteFrames:
.fill Animator.kNumSlots, 0
