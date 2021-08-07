/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

#import "PositionClip.asm"
#import "PositionClipAnimator.asm"
#import "PositionList.asm"
#import "SpriteClip.asm"
#import "SpriteClipAnimator.asm"
#import "MegaSprite.asm"
#import "Animator.asm"
#import "Animation.asm"

// Mapping from Animation name to index and 
// mapping from Animation name to Animation.
.var AnimationIndexByName = Hashtable()
.var AnimationByName = Hashtable()

// Mapping from Animation type to type index.
.var AnimationTypeToTypeIndex = Hashtable()

.function GetAnimationByName(name)
{
    .if (!AnimationByName.containsKey(name))
    {
        .error "Missing Animation: " + name
    }

    .return AnimationByName.get(name)
}

.function GetAnimationIndexByName(name)
{
    .if (!AnimationIndexByName.containsKey(name))
    {
        .error "Missing Animation: " + name
    }

    .return AnimationIndexByName.get(name)
}

//

.filenamespace AnimationData

// Sort animations by type.
.var AnimationsPerType = Hashtable()

// Start with empty list per type.
.for (var i = 0; i < AnimationTypes.size(); i++)
{
    .eval AnimationsPerType.put(AnimationTypes.get(i), List())
}

.for (var i = 0; i < Animations.size(); i++)
{
    .var animation = Animations.get(i);
    .var type = animation.getStructName()

    .eval AnimationsPerType.get(type).add(animation)
}   

// Clear list of all Animations before adding Animations in type order.
.eval Animations = List()

// Keep track of base (first) index of each Animation type.
.var baseIndex = 0
.var AnimationTypeBaseIndices = Hashtable()

// Add Animations in type order.
.for (var i = 0; i < AnimationTypes.size(); i++)
{
    .var type = AnimationTypes.get(i)
    .var animationList = AnimationsPerType.get(type)
    .eval AnimationTypeToTypeIndex.put(type, i)

    // Keep index of first Animation for each type.
    .eval AnimationTypeBaseIndices.put(type, baseIndex)
    .eval baseIndex = baseIndex + animationList.size()

    .for (var j = 0; j < animationList.size(); j++)
    {
        .eval Animations.add(animationList.get(j))
    }

    .if (animationList.size() >= 512)
    {
        .error "Too many Animations (max 511) of type: " + type
    }
}

// Init mapping from Animation name to index
// and mapping from Animation name to Animation.
.for (var i = 0; i < Animations.size(); i++)
{
    .var animation = Animations.get(i);
    .var name = animation.name

    .if (AnimationByName.containsKey(name))
    {
        .error "Found duplicate Animation name: " + name + "   (" + animation.getStructName() + ")"
    }

    .eval AnimationIndexByName.put(name, i)
    .eval AnimationByName.put(name, animation)
}

// Keep track of start address of Animation data per type.
.var AnimationDataAddresses = Hashtable()

//

.segment Code "AnimationData const data"

//

.enum { kSpriteClipIndex, kPositionClipIndex, kNumSprites, kPosSpacing }
.enum { kPositionListIndex = 2}
.enum { kMegaSpriteIndex = 0}

// Raw data sizes of animation types.
.var AnimationTypeSizes = Hashtable()

// Array of animations.
.for (var i = 0; i < Animations.size(); i++)
{
    .var animation = Animations.get(i)
    .var typeName = animation.getStructName()
    .var isFirst = !AnimationDataAddresses.containsKey(typeName)

    .if (isFirst)
    {
        // Keep start address of data for each animation type.
        .eval AnimationDataAddresses.put(typeName, *)
    }

    // Add data of built-in animation types.
    .var data = GetClipAnimationData(List(), animation)
    .eval data = GetFormationClipAnimationData(data, animation)
    .eval data = GetMegaSpriteAnimationData(data, animation)

    // Add data of game specific animation types.
    .eval data = GetGameAnimationData(data, animation)

    .for (var j = 0; j < data.size(); j++)
    {
        .byte data.get(j)
    }

    .if (isFirst)
    {
        // Store size of data per type.
        .eval AnimationTypeSizes.put(typeName, * - AnimationDataAddresses.get(typeName))
    }
}

// Start address of animation data for each type.
BaseAdrLo:
.for (var i = 0; i < AnimationTypes.size(); i++)
{
    .var typeName = AnimationTypes.get(i)
    .if (AnimationDataAddresses.containsKey(typeName))
    {
        .byte <AnimationDataAddresses.get(typeName)
    } 
    else
    {
        .byte 0
    }
}

BaseAdrHi:
.for (var i = 0; i < AnimationTypes.size(); i++)
{
    .var typeName = AnimationTypes.get(i)
    .if (AnimationDataAddresses.containsKey(typeName))
    {
        .byte >AnimationDataAddresses.get(typeName)
    } 
    else
    {
        .byte 0
    }
}

TypeSizes:
.for (var i = 0; i < AnimationTypes.size(); i++)
{
    .var typeName = AnimationTypes.get(i)

    .if (AnimationTypeSizes.containsKey(typeName))
    {
        .byte AnimationTypeSizes.get(typeName)
    }
    else
    {
        //.error "Missing data size for animation type " + typeName
        .byte 0
    }
}

InstanceDataFlipXYMasks:
.for (var i = 0; i < AnimationTypes.size(); i++)
{
    .var typeName = AnimationTypes.get(i)

    .if (AnimationTypeInstanceDataFlipXYMasks.containsKey(typeName))
    {
        .byte AnimationTypeInstanceDataFlipXYMasks.get(typeName)
    }
    else
    {
        .byte 0
    }
}

//

.enum { kTypeAnimationIndexHi, kAnimationIndexLo, kOriginXHiLayer, kOriginXLo, kOriginY, kInstanceData }

// Animations per level.
.var AnimationsStartAddressPerLevel = List()
.for (var i = 0; i < AnimationsPerLevel.size(); i++)
{
    // Keep start address of each level's list of Animations.
    .eval AnimationsStartAddressPerLevel.add(*)

    .var levelAnimations = AnimationsPerLevel.get(i)

    .for (var j = 0; j < levelAnimations.size(); j++)
    {
        .var instance = levelAnimations.get(j)
        .var animation = GetAnimationByName(instance.animationName)
        .var baseIndex = AnimationTypeBaseIndices.get(animation.getStructName());
        .var animationIndex = GetAnimationIndexByName(instance.animationName) - baseIndex;
        .var type = animation.getStructName()
        .var typeIndex = AnimationTypeToTypeIndex.get(type)

        .var originX = min(16383, instance.originX)
        .var originY = instance.originY + kSpriteStartY
        .var layer = min(2, instance.layer)
        .var instanceData = instance.instanceData

        // kTypeAnimationIndexHi
        .byte ((>animationIndex) & %00000001) + (typeIndex << 1)

        // kAnimationIndexLo
        .byte <animationIndex

        // kOriginXHiLayer
        .byte (>originX) + (layer << 6)

        // kOriginXLo, kOriginY
        .byte <originX, originY

        // kInstanceData, type specific instance data.
        .byte instanceData
    }
}

// Start address of Animations per level.
LevelAnimationsLo:
.for (var i = 0; i < AnimationsStartAddressPerLevel.size(); i++)
{
    .byte <AnimationsStartAddressPerLevel.get(i)
}

LevelAnimationsHi:
.for (var i = 0; i < AnimationsStartAddressPerLevel.size(); i++)
{
    .byte >AnimationsStartAddressPerLevel.get(i)
}
