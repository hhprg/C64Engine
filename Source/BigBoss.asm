/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

//

.struct BigBossAnimation { name }
.eval AnimationTypes.add("BigBossAnimation")
.eval AnimationTypeCallbacks.put("BigBossAnimation", Callbacks(BigBoss.Activate, BigBoss.Deactivate, BigBoss.Update))

.function GetBigBossAnimationData(data, animation)
{
    .if (animation.getStructName() == "BigBossAnimation")
    {
    }

    .return data
}

.function GetBigBossAnimationRange(rangeX, animation)
{
    .if (animation.getStructName() == "BigBossAnimation")
    {
        .eval rangeX = MegaSpriteRange(GetMegaSpriteByName("BigBoss"))
        .eval rangeX.maxX = rangeX.maxX + BigBoss.kMaxOffsetX
    }

    .return rangeX
}

//

.filenamespace BigBoss

//

.const kMegaSpriteIndex = GetMegaSpriteIndexByName("BigBoss")
.const kMegaSprite = AllMegaSprites.get(kMegaSpriteIndex)

.const kLocalBoundsX = MegaSpriteBoundsX(kMegaSprite).maxX + kSpriteWidth
.const kLocalBoundsY = MegaSpriteBoundsY(kMegaSprite).maxX + kSpriteHeight
.const kLocalOriginX = kLocalBoundsX / 2
.const kLocalOriginY = kLocalBoundsY / 2
.const kRadiusX = kLocalOriginX
.const kRadiusY = kLocalOriginY
.const kMinScreenY = kLocalOriginY + 12
.const kMaxScreenY = kScreenHeightPixels - kLocalOriginY - 12
.const kMidScreenY = kScreenHeightPixels / 2
.const kBigCannonY = kRadiusY - 10
.const kSmallCannonY = kRadiusY - 40
.const kAverageCannonY = (kBigCannonY + kSmallCannonY) / 2
.const kBottomBigCannonMinScreenY = kLocalOriginY + kBigCannonY
.const kBottomSmallCannonMinScreenY = kLocalOriginY + kSmallCannonY
.const kBottomAverageCannonMinScreenY = kLocalOriginY + kAverageCannonY
.const kTopBigCannonMaxScreenY = kScreenHeightPixels - kLocalOriginY - kBigCannonY
.const kTopSmallCannonMaxScreenY = kScreenHeightPixels - kLocalOriginY - kSmallCannonY
.const kTopAverageCannonMinScreenY = kScreenHeightPixels - kLocalOriginY - kAverageCannonY

.const kPlayerOffsetX = 32 // Target offset relative to player, < 256.
.label kMaxOffsetX = 128   // Max offset relative to world origin, < 256.
.const kMinOffsetX = 8     // > 0 to allow some overshoot without crossing 0.

.const kMaxAccelerationX = 1.0 / 32.0
.const kMaxAccelerationY = 1.0 / 28.0
.const kLookAheadRight = 32
.const kLookAheadLeft = 16
.const kLookAheadY = 32

//

.segment Code "BigBoss code"

//

Activate:
{
                // zpAnimationLo/Hi contain Animation address.

                jsr Animator.DecodeAnimation

                lda #kMegaSpriteIndex
                jsr Animator.InitMegaSprite
                
                lda #kScreenHeightPixels / 2
                sta Position + 1
                sta TargetPosition + 1
                lda #kMaxOffsetX / 2
                sta Position + 0
                sta TargetPosition + 0
                jmp Animator.ExitActivate
}

//

.label Deactivate = Animator.DeactivateShared.DecreaseReferenceCount

//

Update:
{
                // y = animator slot index.
                sty AnimatorSlot

                // Look ahead in horizontal direction player is moving.
                lda #kPlayerOffsetX
                ldx Player.Velocity + 0
                bmi Left
                beq UsePosX
                lda #kPlayerOffsetX + kLookAheadRight
                bne UsePosX
    Left:       lda #kPlayerOffsetX - kLookAheadLeft
    UsePosX:    clc
                adc Player.PositionLo + 0 // Player x.
                tax
                lda Player.PositionHi + 0
                adc #0
                pha

                // Clamp target offset X inside allowed world space window.
                txa
                sec
                sbc Animator.OriginsXLo,y
                tax
                pla
                sbc Animator.OriginsXHi,y
                bpl CheckMaxX
    ClampMinX:  ldx #kMinOffsetX
                bne SetPosX // bra
    CheckMaxX:  bne ClampMaxX
                cpx #kMinOffsetX
                bcc ClampMinX
                cpx #<kMaxOffsetX
                bcc SetPosX
    ClampMaxX:  ldx #<kMaxOffsetX
    SetPosX:    stx TargetPosition + 0

                // Look ahead in vertical direction player is moving.
                lda Player.PositionLo + 1
                ldx Player.Velocity + 1
                bmi Up
                beq UsePosY
                clc
                adc #kLookAheadY
                bcc UsePosY
                lda #$ff
                bne SetPosY
    Up:         sec
                sbc #kLookAheadY
                bcs UsePosY
                lda #0
    UsePosY:
                // Clamp target y to screen.
                cmp #kMinScreenY
                bcs NotMin
                lda #kMinScreenY
    NotMin:     cmp #kMaxScreenY
                bcc SetPosY
                lda #kMaxScreenY
    SetPosY:    sta TargetPosition + 1

                ldx #1
    Next:       // Tween towards target position.
                lda #0
                sec
                sbc PositionFrac,x
                sta NewVelocityFrac
                lda TargetPosition,x
                sbc Position,x
                
                ldy PositionInterpolationShifts,x
    Shift:      cmp #$80 // asr
                ror
                ror NewVelocityFrac
                dey
                bne Shift
                sta NewVelocity

                // Acceleration = delta velocity.
                lda NewVelocityFrac:#0
                sec
                sbc VelocityFrac,x
                sta AccelerationFrac
                lda NewVelocity:#0
                sbc Velocity,x

                // Abs acceleration.
                php
                bpl AbsAcc

                // Negate negative acceleration.
                tay
                lda AccelerationFrac
                eor #$ff
                adc #1 // c = 0
                sta AccelerationFrac
                tya
                eor #$ff
                adc #0
    AbsAcc:     
                // Clamp non-negative acceleration.
                cmp MaxAcceleration,x
                bcc ValidAcc
                bne ClampAcc
                ldy MaxAccelerationFrac,x
                cpy AccelerationFrac:#0
                bcs ValidAcc
    ClampAcc:   lda MaxAccelerationFrac,x
                sta AccelerationFrac
                lda MaxAcceleration,x
    ValidAcc:   plp
                bpl SetAcc

                // Negate again to restore sign of acceleration.
                tay
                lda AccelerationFrac
                eor #$ff
                adc #1 // c = 0
                sta AccelerationFrac
                tya
                eor #$ff
                adc #0
    SetAcc:
                // Add resulting acceleration to velocity.
                tay
                lda AccelerationFrac
                clc
                adc VelocityFrac,x
                sta VelocityFrac,x
                tya
                adc Velocity,x
                sta Velocity,x

                // Add resulting velocity to position.
                lda PositionFrac,x
                clc
                adc VelocityFrac,x
                sta PositionFrac,x
                lda Position,x
                adc Velocity,x
                sta Position,x
                dex
                bmi Done
                jmp Next

    Done:       lda Position + 1
                sec
                sbc #kLocalOriginY // Top of sprites bounding box.
                ldx Position + 0
                ldy AnimatorSlot:#0
                jsr Animator.PrepareUpdate
                jmp Animator.UpdateMegaSprite.AddSprites
}

//

.segment Code "BigBoss const data"

PositionInterpolationShifts:
.byte 5, 4

MaxAccelerationFrac:
.byte <(kMaxAccelerationX * 256), <(kMaxAccelerationY * 256)

MaxAcceleration:
.byte >(kMaxAccelerationX * 256), >(kMaxAccelerationY * 256)

//               

.segment BSS2 "BigBoss data"

// (x, y)   
PositionFrac:
.byte 0, 0

Position:
.byte 0, 0   

VelocityFrac:   
.byte 0, 0

Velocity:   
.byte 0, 0

TargetPosition:
.byte 0, 0

PlayerPositionFrac:
.byte 0, 0

PlayerPosition:
.byte 0, 0
