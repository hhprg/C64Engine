/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

// List of Animation instances per level.
.var AnimationsPerLevel = List()

// List of all animations.
.var Animations = List()

// List of animation types.
.var AnimationTypes = List()

// 
.var AnimationTypeInstanceDataFlipXYMasks = Hashtable()
.const kFlipX = 1 << 6
.const kFlipY = 1 << 7

// Callbacks for each animation type. 
.struct Callbacks { activate, deactivate, update }
.var AnimationTypeCallbacks = Hashtable().lock()

// AnimationInstance is an instance of an animation at a given position, layer ("z") and with type specific instance data.
.struct AnimationInstance { animationName, originX, originY, layer, instanceData }

// Define built-in animation types.

//
// ClipAnimation = animation that has a sprite clip and a position clip (i.e. sprites move along a clip curve).
//
.struct ClipAnimation { name, positionClipName, spriteClipName, numSprites, posSpacing }
.eval AnimationTypes.add("ClipAnimation")
.eval AnimationTypeCallbacks.put("ClipAnimation", Callbacks(Animator.ActivateClip, Animator.DeactivateShared, Animator.UpdateClip))
.eval AnimationTypeInstanceDataFlipXYMasks.put("ClipAnimation", kFlipX + kFlipY)

.function GetClipAnimationData(data, animation)
{
    .if (animation.getStructName() == "ClipAnimation")
    {
        .var positionClipIndex = GetPositionClipIndexByName(animation.positionClipName)
        .var spriteClipIndex = GetSpriteClipIndexByName(animation.spriteClipName)
        .var posSpacing = animation.posSpacing - 1 // Because doing sbc with c=0 in Animator.Update.SetVirSpritePositions!
        .var numSprites = animation.numSprites

        // kSpriteClipIndex, kPositionClipIndex
        .eval data.add(spriteClipIndex, positionClipIndex)

        // kNumSprites, kPosSpacing
        .eval data.add(numSprites, posSpacing)
    }

    .return data
}

.function GetClipAnimationRange(rangeX, animation)
{
    .if (animation.getStructName() == "ClipAnimation")
    {
        .var positionClip = GetPositionClipByName(animation.positionClipName)
        .eval rangeX = PositionClipRange(positionClip)
    }

    .return rangeX
}

//
// FormationClipAnimation = animation that has a sprite clip, a position list (i.e. fixed sprite positions) and a position clip that moves the root position.
//
.struct FormationClipAnimation { name, positionListName, spriteClipName, positionClipName }
.eval AnimationTypes.add("FormationClipAnimation")
.eval AnimationTypeCallbacks.put("FormationClipAnimation", Callbacks(Animator.ActivateFixed, Animator.DeactivateShared, Animator.UpdateFixed))

.function GetFormationClipAnimationData(data, animation)
{
    .if (animation.getStructName() == "FormationClipAnimation")
    {
        .var spriteClipIndex = GetSpriteClipIndexByName(animation.spriteClipName)
        .var positionListIndex = GetPositionListIndexByName(animation.positionListName)
        .var positionClipIndex = GetPositionClipIndexByName(animation.positionClipName)

        // kSpriteClipIndex, kPositionClipIndex
        .eval data.add(spriteClipIndex, positionClipIndex)

        // kPositionListIndex
        .eval data.add(positionListIndex)
    }

    .return data
}

.function GetFormationClipAnimationRange(rangeX, animation)
{
    .if (animation.getStructName() == "FormationClipAnimation")
    {
        .var positionClip = GetPositionClipByName(animation.positionClipName)
        .var positionList = GetPositionListByName(animation.positionListName) 
        .var clipRangeX = PositionClipRange(positionClip)
        .var listRangeX = PositionListRange(positionList)

        .eval rangeX = PositionRange(clipRangeX.minX + listRangeX.minX, clipRangeX.maxX + listRangeX.maxX)
    }

    .return rangeX
}

//
// MegaSpriteAnimation = animation that has a mega sprite and a position clip that moves the root position.
//
.struct MegaSpriteAnimation { name, megaSpriteName, positionClipName }
.eval AnimationTypes.add("MegaSpriteAnimation")
.eval AnimationTypeCallbacks.put("MegaSpriteAnimation", Callbacks(Animator.ActivateMegaSprite, Animator.DeactivateMegaSprite, Animator.UpdateMegaSprite))

.function GetMegaSpriteAnimationData(data, animation)
{
    .if (animation.getStructName() == "MegaSpriteAnimation")
    {
        .var megaSpriteIndex = GetMegaSpriteIndexByName(animation.megaSpriteName)
        .var positionClipIndex = GetPositionClipIndexByName(animation.positionClipName)

        // kMegaSpriteIndex, kPositionClipIndex
        .eval data.add(megaSpriteIndex, positionClipIndex)
    }

    .return data
}

.function GetMegaSpriteAnimationRange(rangeX, animation)
{
    .if (animation.getStructName() == "MegaSpriteAnimation")
    {
        .var positionClip = GetPositionClipByName(animation.positionClipName)
        .var megaSprite = GetMegaSpriteByName(animation.megaSpriteName) 
        .var clipRangeX = PositionClipRange(positionClip)
        .var spriteRangeX = MegaSpriteRange(megaSprite)

        .eval rangeX = PositionRange(clipRangeX.minX + spriteRangeX.minX, clipRangeX.maxX + spriteRangeX.maxX)
    }

    .return rangeX
}

//

#import "GameAnimation.asm"

