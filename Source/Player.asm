/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Player

//

.segment Code "Player code"         

.const kSpriteAnimatorSlot = SpriteClipAnimator.kNumSharedSlots

.const kOriginX = kSpriteWidth / 2
.const kOriginY = kSpriteHeight / 2
.const kLayer = 1
.const kAcceleration = 32;   
.const kMaxSpeed = 2
.const kMinPositionY = kOriginY    
.const kMaxPositionY = kScreenHeightPixels - kOriginY

.const kMinPositionX = kOriginX
.const kMaxPositionX = kNumVisibleScreenPixels - kMinPositionX 

.const kNumCollisionChecks = 4   
.const kCollisionDistanceX = kSpriteWidth - 4   
.const kCollisionDistanceY = kSpriteHeight - 4   
.const kSpawnBlinkDuration = 8 // #frames, must be power of 2.
.const kSpawnDuration = kSpawnBlinkDuration * 10 // #frames
.const kSpawnDelay = 50 // #frames   

.enum { kComponentX=0, kComponentY=1 }

// Flags.
.enum { kIsVisibleFlag = 1, kCanMoveFlag = 2, kCanCollide = 4 }

.struct State {name, enter, update, flags}

// States.
.const kAliveState = State("Alive", EnterAliveState, UpdateAliveState, kIsVisibleFlag | kCanMoveFlag | kCanCollide)
.const kSpawnState = State("Spawn", EnterSpawnState, UpdateSpawnState, kCanMoveFlag)
.const kWaitToSpawnState = State("WaitToSpawn", EnterWaitToSpawnState, UpdateWaitToSpawnState, 0)    
.const kExplodeState = State("Explode", EnterExplodeState, UpdateExplodeState, kIsVisibleFlag)

.var AllStates = List()   
.eval AllStates.add(kAliveState)
.eval AllStates.add(kSpawnState)
.eval AllStates.add(kWaitToSpawnState)
.eval AllStates.add(kExplodeState)

.var StateNameToIndex = Hashtable()

.for (var i = 0; i < AllStates.size(); i++)   
{
    .eval StateNameToIndex.put(AllStates.get(i).name, i)
}

.macro SwitchState(state)   
{
                ldx #StateNameToIndex.get(state.name)
                jmp EnterState
}

// y = component index (0 = x, 1 = y)
.macro AddAcceleration(acceleration)
{
                lda #<acceleration
                clc
                adc VelocityFrac,y               
                sta VelocityFrac,y
                lda #>acceleration               
                adc Velocity,y
                sta Velocity,y
}

//

Init:
{
                ldx.zp LevelData.zpCurrent
                lda LevelData.PlayerStartPosXLo,x
                sta PositionLo
                lda LevelData.PlayerStartPosXHi,x
                sta PositionHi
                lda LevelData.PlayerStartPosY,x
                sta PositionLo + 1               

                SwitchState(kSpawnState)               
}

// 

UpdateVelocity:
{
                // y = component index (0 = x, 1 = y)
                ldy #1
    Next:       lda StateFlags
                and #kCanMoveFlag
                beq Decelerate
                lda Input.JoystickBits   
                and JoystickDirBits,y
                bne Accelerate
            
    Decelerate:
                // Apply velocity damping.
                ldx VelocityFrac,y     
                lda Velocity,y               
                ApplyDamping()
                sta Velocity,y
                txa
                sta VelocityFrac,y
    Done:       dey               
                bpl Next         
                rts
            
    Accelerate: and JoystickNegDirBits,y               
                bne NegDir
            
    PosDir:     AddAcceleration(kAcceleration)
                bmi NegVel
    PosVel:     cmp #kMaxSpeed
                bcc Done
                lda #kMaxSpeed
                bpl Clamp // bra               
            
    NegDir:     AddAcceleration(-kAcceleration)
                bpl PosVel
    NegVel:     cmp #-kMaxSpeed
                bcs Done
                lda #-kMaxSpeed
    Clamp:      sta Velocity,y
                lda #0               
                sta VelocityFrac,y
                beq Done // bra
}

//

.macro UpdatePosition()
{
                ldy #1
    Next:       lda VelocityFrac,y
                clc
                adc PositionFrac,y
                sta PositionFrac,y
                ldx #0 // x = hi-byte of sign extended velocity.
                lda Velocity,y
                bpl PosHi
                dex
    PosHi:      adc PositionLo,y
                sta PositionLo,y
                txa
                adc PositionHi,y
                sta PositionHi,y
                dey
                bpl Next
}
            
//

// In/out: x = frac, a = int
.macro ApplyDamping()
{
                php
                bpl Positive0

                // Negate.               
                stx SignedFrac
                sta SignedInt
                lda #0
                sec
                sbc SignedFrac:#0         
                tax
                lda #0
                sbc SignedInt:#0
            
    Positive0:  stx AbsFrac
                sta AbsInt
                sta AbsIntShifted
                txa               

                // abs * 16
                //asl
                //rol AbsIntShifted
                asl
                rol AbsIntShifted
                asl
                rol AbsIntShifted
                asl
                rol AbsIntShifted
                
                // abs * 16 - abs
                sec               
                sbc AbsFrac:#0
                sta ResultFrac
                lda AbsIntShifted:#0
                sbc AbsInt:#0
                
                // (abs * 16 - abs) / 16 = 15 * abs / 16
                //lsr
                //ror ResultFrac
                lsr
                ror ResultFrac
                lsr
                ror ResultFrac
                lsr
                ror ResultFrac
                
                plp
                bpl Positive1
                
                // Negate.
                sta ResultInt
                lda #0
                sec
                sbc ResultFrac         
                sta ResultFrac
                lda #0
                sbc ResultInt:#0
    Positive1:  ldx ResultFrac:#0
}

//

UpdateTask:
{
                jsr UpdateCollision
                jsr UpdateState               
                ReturnFromTask()
}

//

Update:
{
                // Update velocity and position.
                jsr UpdateVelocity
                UpdatePosition()

                // Clamp position x relative to camera.
                lda PositionLo
                sec
                sbc Camera.PositionXLo
                tay
                lda PositionHi
                sbc Camera.PositionXHi
                bne CheckMax
                cpy #<kMinPositionX               
                bcs CheckMax
                ldy #<kMinPositionX
                lda #>kMinPositionX
                bpl Set // bra
   
    CheckMax:   cmp #>kMaxPositionX         
                bcc Set
                cpy #<kMaxPositionX
                bcc Set
                ldy #<kMaxPositionX
                lda #>kMaxPositionX
    Set:        tax               
                tya
                clc
                adc Camera.PositionXLo
                sta PositionLo
                txa
                adc Camera.PositionXHi
                sta PositionHi
                
                // Clamp y position.
                lda PositionLo + 1
                cmp #kMinPositionY
                bcs NotMinY
                lda #kMinPositionY
                bne ClampY // bra
    NotMinY:    cmp #kMaxPositionY
                bcc NotMaxY
                lda #kMaxPositionY
    ClampY:     ldx #0               
                stx PositionFrac + 1
                stx VelocityFrac + 1
                stx Velocity + 1
                sta PositionLo + 1
   
    NotMaxY:    lda StateFlags
                and #kIsVisibleFlag
                beq AddTask
                
                // Add vir sprite.
                
                // x = vir sprite index.                
                ldx Multiplexer.NumVirSprites
                stx VirSpriteIndex
                
                lda SpriteColor
                ora #%01000000 // Layer 1 << 6.
                sta Multiplexer.VirSpriteColorLayers,x
                lda SpriteClipAnimator.CurrentFrames + kSpriteAnimatorSlot      
                sta Multiplexer.VirSpritePointers,x

                // World space position of top-left corner of sprite.
                lda PositionLo + 1         
                clc
                adc #kSpriteStartY - kOriginY
                sta Multiplexer.zpVirSpritePosY,x
                lda PositionLo         
                sbc #kOriginX - 1 // c = 0
                sta Multiplexer.VirSpritePosXLo,x
                lda PositionHi         
                sbc #0
                sta Multiplexer.VirSpritePosXHi,x

                // From world space to screen space.
                lda Multiplexer.VirSpritePosXLo,x
                clc
                adc Camera.zpWorldToScreenPositionXLo
                sta Multiplexer.VirSpritePosXLo,x
                lda Multiplexer.VirSpritePosXHi,x
                adc Camera.zpWorldToScreenPositionXHi
                sta Multiplexer.VirSpritePosXHi,x

                inc Multiplexer.NumVirSprites
                inc Multiplexer.NumVirSpritesPerLayer + kLayer      
   
    AddTask:    TaskInput(UpdateTask)
                jmp Task.AddHighPriority
}

//   

UpdateState:
{
                ldx State
                lda UpdateStateHi,x 
                pha
                lda UpdateStateLo,x
                pha
                rts // jmp
}

UpdateAliveState:
{
                rts
}
   
UpdateSpawnState:               
{
                dec SpawnTimer
                bne Update
                SwitchState(kAliveState)

    Update:     lda SpawnTimer               
                and #kSpawnBlinkDuration
                php
                lda StateFlags
                and #(kIsVisibleFlag ^ $ff)
                plp
                beq Set
                ora #kIsVisibleFlag
    Set:        sta StateFlags
                rts
}           
   
UpdateWaitToSpawnState:               
{
                dec SpawnTimer         
                bne Exit
                SwitchState(kSpawnState)
    Exit:       rts               
}           
            
UpdateExplodeState:               
{
                lda SpriteClipAnimator.Playing + kSpriteAnimatorSlot
                bne Exit
                SwitchState(kWaitToSpawnState)
    Exit:       rts
}

//

// x = state
EnterState:
{
                stx State
                lda EnterStateFlags,x
                sta StateFlags
                lda EnterStateHi,x 
                pha
                lda EnterStateLo,x
                pha
                rts
}

//

EnterWaitToSpawnState:               
{
                lda #kSpawnDelay
                sta SpawnTimer
                rts
}

//

EnterAliveState:               
{
                rts
}

//

EnterExplodeState:   
{
                jsr StopAnimation
                
                clc // One shot.
                PlaySpriteClipSlot("Explosion", kSpriteAnimatorSlot)
                sta SpriteColor
                rts
}

//

EnterSpawnState:
{
                jsr StopAnimation

                sec // Loop
                PlaySpriteClipSlot("MainShipLoop", kSpriteAnimatorSlot)
                sta SpriteColor
                lda #kSpawnDuration
                sta SpawnTimer
                rts
}               

//

StopAnimation:
{
                lda SpriteClipAnimator.ReferenceCounts + kSpriteAnimatorSlot
                beq Done
                ldx #kSpriteAnimatorSlot
                jmp SpriteClipAnimator.Deactivate
    Done:       rts               
}

//

UpdateCollision:
{
                lda StateFlags
                and #kCanCollide
                bne Update
                rts
    Update:     ldx VirSpriteIndex
                lda Multiplexer.zpVirSpritePosY,x
                clc
                adc #kCollisionDistanceY
                sta MaxY
                sbc #(kCollisionDistanceY * 2 - 2) // c = 0
                sta MinY

                lda Multiplexer.VirSpritePosXLo,x
                adc #kCollisionDistanceX // c = 1
                sta MaxXLo
                lda Multiplexer.VirSpritePosXHi,x
                adc #0
                sta MaxXHi
                lda Multiplexer.VirSpritePosXLo,x
                sbc #(kCollisionDistanceX - 1) // c = 0
                sta MinXLo
                lda Multiplexer.VirSpritePosXHi,x
                sbc #0
                bcs SetMinX
                lda #0     // Clamp MinX to 0.
                sta MinXLo
    SetMinX:    sta MinXHi
            
                txa
                ldx Multiplexer.NumVirSprites
    Prev:       dex
                cmp Multiplexer.zpSortedVirSprites,x         
                bne Prev 
                
                // Greedy checks, only check against vir sprites within N (sorted) indices.
                txa
                cmp #kNumCollisionChecks / 2
                bcs CenterIndex
                lda #kNumCollisionChecks / 2 + 1 // c = 0
    CenterIndex:sbc #kNumCollisionChecks / 2
                tay
                adc #kNumCollisionChecks     // c = 1
                cmp Multiplexer.NumVirSprites                        
                bcc StopIndex
                lda Multiplexer.NumVirSprites
    StopIndex:  sta Stop               
            
    Next:       ldx Multiplexer.zpSortedVirSprites,y
   
                // Reject based on y.
                lda Multiplexer.zpVirSpritePosY,x         
                cmp MinY:#0                              
                bcc Reject
                cmp MaxY:#0                              
                bcs Reject
            
                // Reject collision against itself.
                // Todo: Reject based on collision layer?
                cpx VirSpriteIndex
                beq Reject
                
                // Reject based on x.
                lda Multiplexer.VirSpritePosXLo,x         
                cmp MaxXLo:#0                              
                lda Multiplexer.VirSpritePosXHi,x         
                sbc MaxXHi:#0                              
                bcs Reject

                lda Multiplexer.VirSpritePosXLo,x         
                cmp MinXLo:#0                              
                lda Multiplexer.VirSpritePosXHi,x         
                sbc MinXHi:#0                              
                bcc Reject
            
                SwitchState(kExplodeState)               
            
    Reject:     iny                     
                cpy Stop:#0
                bcc Next
                rts
}

//

.segment Code "Player const data"

JoystickDirBits:
.byte kJoystickLeftOrRightBits, kJoystickUpOrDownBits

JoystickNegDirBits:
.byte kJoystickLeftBit, kJoystickUpBit

EnterStateLo:   
.for (var i = 0; i < AllStates.size(); i++)
{
    .byte <(AllStates.get(i).enter - 1)
}  

EnterStateHi:   
.for (var i = 0; i < AllStates.size(); i++)
{
    .byte >(AllStates.get(i).enter - 1)
}  

UpdateStateLo:   
.for (var i = 0; i < AllStates.size(); i++)
{
    .byte <(AllStates.get(i).update - 1)
}  

UpdateStateHi:   
.for (var i = 0; i < AllStates.size(); i++)
{
    .byte >(AllStates.get(i).update - 1)
}  

EnterStateFlags:
.for (var i = 0; i < AllStates.size(); i++)
{
    .byte AllStates.get(i).flags
}  

//

.segment BSS2 "Player data"
   
State:  
.byte 0

StateFlags:
.byte 0

SpawnTimer:
.byte 0

SpriteColor:
.byte 0

VirSpriteIndex:
.byte 0

// (x, y)   
PositionFrac:
.byte 0, 0

PositionLo:
.byte 0, 0   

PositionHi:
.byte 0, 0   

VelocityFrac:   
.byte 0, 0

Velocity:   
.byte 0, 0
