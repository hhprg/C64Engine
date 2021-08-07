/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace AnimationTrigger   

//

.segment Zeropage "AnimationTrigger zeropage data"

zpBoundaryDataLo:
.fill 1, 0
zpBoundaryDataHi:
.fill 1, 0

zpAnimationIndexLo:
.fill 1, 0
zpAnimationIndexHi:
.fill 1, 0

zpAnimationInstanceLo:
.fill 1,0
zpAnimationInstanceHi:
.fill 1,0

//

.segment Code "AnimationTrigger code"

.const kTriggerQueueSize = 8 // Must be power of 2.
.const kActivationScreenWidth = kScreenWidthPixels
.const kTriggerWindowPadding = 4

// Find max number of Animations for any level.
.var kMaxAnimations = 0

.for (var level = 0; level < AnimationsPerLevel.size(); level++)
{
    .eval kMaxAnimations = max(kMaxAnimations, AnimationsPerLevel.get(level).size())
}

.const kNumAnimationStatuses = (kMaxAnimations + 7) / 8

// Store AnimationIndex hi-byte in topmost N bits of boundary x hi-byte.
.const kMaxAnimationIndices = 1024 // Must be power of 2.
.const kNumAnimationIndexHiBits = round(log10(kMaxAnimationIndices)/log10(2)) - 8
.const kAnimationIndexHiShift = 8 - kNumAnimationIndexHiBits
.const kAnimationIndexHiBits = ((1 << kNumAnimationIndexHiBits) - 1) << kAnimationIndexHiShift
.const kAnimationIndexHiDiv8Shift = kAnimationIndexHiShift - 5

// Number of Animation update slots.
.const kMaxUpdateSlots = 8

// Boundary = Animation instance index (per level), position (x), which side (min or max) of bounding area and type of Animation.
.struct Boundary { animationIndex, x, isMin, typeIndex }

// These values are used as offsets into struct.
.enum { kAnimationIndexLo, kBoundaryLo, kBoundaryHiAnimationIndexHi, kBoundarySize }

// Add Animation boundaries per level.
.var BoundariesPerLevel = List()
.for (var level = 0; level < AnimationsPerLevel.size(); level++)
{
    .var levelAnimations = AnimationsPerLevel.get(level)
    .var animationBoundaries = List()

    .eval BoundariesPerLevel.add(animationBoundaries)

    .for (var i = 0; i < levelAnimations.size(); i++)
    {
        // Find bounding interval in x.
        .var instance = levelAnimations.get(i)
        .var animation = AnimationByName.get(instance.animationName)
        .var type = animation.getStructName()
        .var typeIndex = AnimationTypeToTypeIndex.get(type)
        .var rangeX = PositionRange(0,0)

        .eval rangeX = GetClipAnimationRange(rangeX, animation)
        .eval rangeX = GetFormationClipAnimationRange(rangeX, animation)
        .eval rangeX = GetMegaSpriteAnimationRange(rangeX, animation)
        .eval rangeX = GetGameAnimationRange(rangeX, animation)

        .if (rangeX.maxX > kMaxPosX)
        {
            .error "Position X out of range (max is " + kMaxPosX + "): " + animation.animationName
        }

        .var minX = rangeX.minX + instance.originX - kTriggerWindowPadding
        .var maxX = rangeX.maxX + instance.originX + kTriggerWindowPadding
        .eval minX = minX < kActivationScreenWidth ? 0 : minX - kActivationScreenWidth
        .eval maxX = maxX + kSpriteWidth

        .eval animationBoundaries.add(Boundary(i, minX, true, typeIndex))         
        .eval animationBoundaries.add(Boundary(i, maxX, false, typeIndex))
    }
}

// Sort boundaries per level in ascending order.
.for (var level = 0; level < BoundariesPerLevel.size(); level++)
{
    .var animationBoundaries = BoundariesPerLevel.get(level)

    .for (var i = 0; i < animationBoundaries.size() - 1; i++)
    {
        .var minX = animationBoundaries.get(i).x
      
        .for (var j = i + 1; j < animationBoundaries.size(); j++)
        {
            .var x = animationBoundaries.get(j).x
            .if (x < minX)
            {
                .var boundary = animationBoundaries.get(i)
                .eval animationBoundaries.set(i, animationBoundaries.get(j))
                .eval animationBoundaries.set(j, boundary)
                .eval minX = x
            }
        }
    }

    // Verify that we don't use more Animators than available at any point in time.
    .var numActiveAnimators = 0
    .for (var i = 0; i < animationBoundaries.size(); i++)
    {
        .var boundary = animationBoundaries.get(i)
/*
        .if ((boundary.typeIndex == AnimationTypeToTypeIndex.get("ClipAnimation")) || 
             (boundary.typeIndex == AnimationTypeToTypeIndex.get("FormationClipAnimation")))
*/             
        {
            .if (boundary.isMin)
            {
                .eval numActiveAnimators = numActiveAnimators + 1
                .if (numActiveAnimators > Animator.kNumSlots)
                {
                    .error "Too many Animators used (max " + Animator.kNumSlots + ")"
                }
             }
            else
            {
                .eval numActiveAnimators = numActiveAnimators - 1
            }
        }
    }   

    // Add begin/end boundary markers first/last in list.
    .eval animationBoundaries.reverse()
    .eval animationBoundaries.add(Boundary(0, 0, false, 0))         
    .eval animationBoundaries.reverse()
    .eval animationBoundaries.add(Boundary(0, $ffff, true, 0))      
}

//

Init:
{
                lda #0
                ldy #kNumAnimationStatuses
    ClearStatus:dey                  
                sta AnimationStatuses,y
                bne ClearStatus

                sta QueueTail
                sta QueueHead

                ldy #kMaxUpdateSlots
                lda #kUndefined                  
    ClearSlot:  dey
                sta UpdateAnimationIndicesLo,y
                sta UpdateAnimationIndicesHi,y
                bne ClearSlot
               
                // Must be done after setting initial Camera position.
                ldy.zp LevelData.zpCurrent
                lda BoundaryDataLo,y
                sta zpBoundaryDataLo
                lda BoundaryDataHi,y
                sta zpBoundaryDataHi

    Try:        jsr TryNextBoundary
                bcc Done
                jsr NextBoundary
                jsr GetAnimationIndexDiv8
                tax
                ldy #kAnimationIndexLo
                lda (zpBoundaryDataLo),y
                and #7
                tay
                lda Bits,y
                eor AnimationStatuses,x                  
                sta AnimationStatuses,x
                jmp Try // bra

    Done:       // Activate all active animations.            
                ldy #0
    Next:       lda AnimationStatuses,y
                beq Skip

                tya
                pha

                lda #0
                sta zpAnimationIndexHi
                tya
                asl // x8
                rol zpAnimationIndexHi
                asl
                rol zpAnimationIndexHi
                asl
                rol zpAnimationIndexHi
                sta zpAnimationIndexLo                

                lda AnimationStatuses,y
    NextAnim:   lsr
                bcc SkipAnim
                pha
                jsr GetAnimationInstance
                jsr ActivateAnimation
                pla
    SkipAnim:   inc zpAnimationIndexLo
                tay
                bne NextAnim

                pla
                tay
    Skip:       iny                  
                cpy #kNumAnimationStatuses
                bne Next         
                rts               
}           
 
//
 
NextBoundary:
{
                // c = 1
                lda zpBoundaryDataLo
                adc #kBoundarySize - 1 // c = 1
                sta zpBoundaryDataLo
                bcc Done
                inc zpBoundaryDataHi
    Done:       rts                  
}

//

TryNextBoundary:
{
                // Returns c = 1 if entered next boundary, c = 0 otherwise.
                ldy #kBoundaryHiAnimationIndexHi + kBoundarySize
                lda (zpBoundaryDataLo),y
                and #~kAnimationIndexHiBits
                tsx
                pha
                lda Camera.PositionXDiv2Hi
                cmp kStackAdr,x
                txs
                bne Done
                ldy #kBoundaryLo + kBoundarySize
                lda Camera.PositionXDiv2Lo
                cmp (zpBoundaryDataLo),y
    Done:       rts
}

//

// Update runs on main task.
Update:
{
    Right:               
    {
        Try:        jsr TryNextBoundary
                    bcc Left
                    jsr NextBoundary   // Todo: First check if ToggleAnimator successful?
                    jsr ToggleAnimator // Enter/exit handler here.                
                    jmp Try
    }
   
    Left:    
    {
        Try:        ldy #kBoundaryHiAnimationIndexHi
                    lda (zpBoundaryDataLo),y
                    and #~kAnimationIndexHiBits
                    tsx
                    pha
                    lda Camera.PositionXDiv2Hi
                    cmp kStackAdr,x
                    txs
                    bne Decide
                    lda Camera.PositionXDiv2Lo
                    ldy #kBoundaryLo
                    cmp (zpBoundaryDataLo),y
        Decide:     bcs Done
                    jsr ToggleAnimator               
                    lda zpBoundaryDataLo
                    sec
                    sbc #kBoundarySize
                    sta zpBoundaryDataLo
                    bcs Try
                    dec zpBoundaryDataHi
                    bcc Try // bra
    }
   
    Done:           rts
}
   
//

.macro UpdateSlot()
{
    Start:
                ldy Instance:#kUndefined
                bmi Skip
    .label CodeLo = * + 1
    .label CodeHi = * + 2
                jsr kDefaultAdr
    Skip:
    .label Size = * - Start
}

UpdateActive:
{
    Slot:       UpdateSlot()
    .for (var i = 1; i < kMaxUpdateSlots; i++)
    {
                UpdateSlot()
    }
                rts
}

//

GetAnimationInstance:
{
                // Address of animation instance data.
                lda zpAnimationIndexLo // x6 = kAnimationInstanceSize
                ldy zpAnimationIndexHi
                sty zpAnimationInstanceHi
                asl
                rol zpAnimationInstanceHi
                adc zpAnimationIndexLo
                sta zpAnimationInstanceLo
                lda zpAnimationInstanceHi
                adc zpAnimationIndexHi
                sta zpAnimationInstanceHi
                lda zpAnimationInstanceLo
                asl
                rol zpAnimationInstanceHi
                ldy.zp LevelData.zpCurrent
                adc AnimationData.LevelAnimationsLo,y
                sta zpAnimationInstanceLo
                lda zpAnimationInstanceHi
                adc AnimationData.LevelAnimationsHi,y
                sta zpAnimationInstanceHi
                ldy #0 // kTypeAnimationIndexHi
                lda (zpAnimationInstanceLo),y // a, x = type index.
                lsr
                tax
                rts
}

//

GetAnimationIndexDiv8:
{
                ldy #kAnimationIndexLo
                lda (zpBoundaryDataLo),y
                lsr
                lsr
                lsr
                sta LoBits
                ldy #kBoundaryHiAnimationIndexHi
                lda (zpBoundaryDataLo),y
                and #kAnimationIndexHiBits
    .for (var i = 0; i < kAnimationIndexHiDiv8Shift; i++)
    {
                lsr
    }
                ora LoBits:#0
                rts
}

//

GetAnimationIndexHi:
{
                ldy #kBoundaryHiAnimationIndexHi
                lda (zpBoundaryDataLo),y
                and #kAnimationIndexHiBits
                asl
    .for (var i = 0; i < kAnimationIndexHiShift; i++)
    {
                rol
    }
                rts    
}

//

ToggleAnimator:
{   
                // Add animation index to head of queue.
                lda QueueHead            
                and #kTriggerQueueSize - 1
                tax
                inc QueueHead

                ldy #kBoundaryHiAnimationIndexHi
                lda (zpBoundaryDataLo),y
                and #kAnimationIndexHiBits
                asl
    .for (var i = 0; i < kAnimationIndexHiShift; i++)
    {
                rol
    }
                sta QueueAnimationIndicesHi,x
                ldy #kAnimationIndexLo
                lda (zpBoundaryDataLo),y               
                sta QueueAnimationIndicesLo,x
                and #7
                tax
                jsr GetAnimationIndexDiv8
                tay

                lda AnimationStatuses,y
                eor Bits,x
                sta AnimationStatuses,y
                and Bits,x
                beq Deactivate

                TaskInput(ActivateAnimationTask)
                bne AddTask // bra               

    Deactivate: TaskInput(DeactivateAnimationTask)
    AddTask:    jmp Task.AddLowPriority
}

//

Dequeue:
{
                lda QueueTail
                and #kTriggerQueueSize - 1
                tax
                lda QueueAnimationIndicesHi,x
                sta zpAnimationIndexHi
                lda QueueAnimationIndicesLo,x
                sta zpAnimationIndexLo
                jsr GetAnimationInstance
                inc QueueTail
                rts
}

//

ActivateAnimationTask:
{
                jsr Dequeue
                jsr ActivateAnimation
                ReturnFromTask()
}

//

DeactivateAnimationTask:
{
                jsr Dequeue
                jsr DeactivateAnimation
                ReturnFromTask()
}

//

ActivateAnimation:
{
                // zpAnimationInstanceLo/Hi
                // a, x = type index.
                pha
                lda #>(Return - 1)
                pha
                lda #<(Return - 1)
                pha
                lda ActivateHi,x
                pha
                lda ActivateLo,x
                pha
                rts // Call Activate.

    Return:     // x = type instance index (e.g. animator slot).

                // Find free update slot.
                ldy #kMaxUpdateSlots - 1
    TrySlot:    lda UpdateAnimationIndicesHi,y
                bmi Found
                dey
                bpl TrySlot
   
    Found:      lda zpAnimationIndexLo
                sta UpdateAnimationIndicesLo,y
                lda zpAnimationIndexHi
                sta UpdateAnimationIndicesHi,y

                // Add to UpdateActive.
                lda MulUpdateSlotCodeSize,y
                tay
                txa // x = type instance index
                sta UpdateActive.Slot.Instance,y
                pla
                tax // x = type index.
                lda UpdateLo,x
                sta UpdateActive.Slot.CodeLo,y
                lda UpdateHi,x
                sta UpdateActive.Slot.CodeHi,y
                rts
}

//

DeactivateAnimation:
{
                // zpAnimationInstanceLo/Hi
                // a, x = type index.
                lda DeactivateHi,x
                pha
                lda DeactivateLo,x
                pha

                ldy #kMaxUpdateSlots - 1
    TrySlot:    lda zpAnimationIndexLo
                cmp UpdateAnimationIndicesLo,y
                bne Next
                lda zpAnimationIndexHi
                cmp UpdateAnimationIndicesHi,y
                beq Found
    Next:       dey
                bpl TrySlot

    Found:      // Remove from UpdateActive.
                ldx MulUpdateSlotCodeSize,y
                lda UpdateActive.Slot.Instance,x
                pha
                lda #kUndefined
                sta UpdateAnimationIndicesLo,y
                sta UpdateAnimationIndicesHi,y
                sta UpdateActive.Slot.Instance,x

                pla
                tay // y = type instance index (e.g. animator slot index)
                rts // Call Deactivate.
}

//

.segment Code "AnimationTrigger const data"

// AOS to support more than 256 boundaries.
// Todo: Multiple sets of boundaries for different types to trigger (animations, audio etc.)?

// Boundary data per level.
.var BoundaryDataPerLevel = List()

.for (var level = 0; level < BoundariesPerLevel.size(); level++)
{
    .eval BoundaryDataPerLevel.add(*)
    .var animationBoundaries = BoundariesPerLevel.get(level)

    .for (var i = 0; i < animationBoundaries.size(); i++)
    {
        .var boundary = animationBoundaries.get(i)          
        .var x = boundary.x

        // Store at lower precision to gain one bit for storing animation index.
        .if (boundary.isMin)
        {
            .eval x = floor(x / 2)
        }
        else
        {
            .eval x = ceil(x / 2)
        }

        // kAnimationIndexLo
        .byte <boundary.animationIndex

        // kBoundaryLo, kBoundaryHiAnimationIndexHi
        .byte <x, (>x) + ((>boundary.animationIndex) << kAnimationIndexHiShift)
    }   
}

// Start address of boundary data per level.
BoundaryDataLo:
.for (var i = 0; i < BoundaryDataPerLevel.size(); i++)
{
    .byte <BoundaryDataPerLevel.get(i)
}

BoundaryDataHi:
.for (var i = 0; i < BoundaryDataPerLevel.size(); i++)
{
    .byte >BoundaryDataPerLevel.get(i)
}

// Type callbacks, "methods".
.for (var i = 0; i < AnimationTypes.size(); i++) 
{ 
    .var typeName = AnimationTypes.get(i)

    .if (!AnimationTypeCallbacks.containsKey(typeName))
    {
        .error "Missing animation callbacks for type " + typeName 
    }
}

ActivateLo:
.for (var i = 0; i < AnimationTypes.size(); i++) { .byte <(AnimationTypeCallbacks.get(AnimationTypes.get(i)).activate - 1)}
ActivateHi:
.for (var i = 0; i < AnimationTypes.size(); i++) { .byte >(AnimationTypeCallbacks.get(AnimationTypes.get(i)).activate - 1)}

DeactivateLo:
.for (var i = 0; i < AnimationTypes.size(); i++) { .byte <(AnimationTypeCallbacks.get(AnimationTypes.get(i)).deactivate - 1)}
DeactivateHi:
.for (var i = 0; i < AnimationTypes.size(); i++) { .byte >(AnimationTypeCallbacks.get(AnimationTypes.get(i)).deactivate - 1)}

UpdateLo:
.for (var i = 0; i < AnimationTypes.size(); i++) { .byte <(AnimationTypeCallbacks.get(AnimationTypes.get(i)).update - 0)}
UpdateHi:
.for (var i = 0; i < AnimationTypes.size(); i++) { .byte >(AnimationTypeCallbacks.get(AnimationTypes.get(i)).update - 0)}

MulUpdateSlotCodeSize:
.for (var i = 0; i < kMaxUpdateSlots; i++)
{
    .byte i * UpdateActive.Slot.Size
}

.label Bits = CharTileMap.Bits

//

.segment BSS2 "AnimationTrigger data"

// Todo: Interleave bits to represent status of multiple Animation types.         
AnimationStatuses:
.fill kNumAnimationStatuses, 0

// Tail (index of next element to process).
QueueTail:
.byte 0

// Head (index of where to add next element).
QueueHead:
.byte 0

QueueAnimationIndicesLo:
.fill kTriggerQueueSize, 0

QueueAnimationIndicesHi:
.fill kTriggerQueueSize, 0

UpdateAnimationIndicesLo:
.fill kMaxUpdateSlots, 0

UpdateAnimationIndicesHi:
.fill kMaxUpdateSlots, 0
