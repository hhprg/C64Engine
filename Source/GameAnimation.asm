/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

#import "BigBoss.asm"
#import "MiniBoss.asm"

// Get game specific animation raw data.
.function GetGameAnimationData(data, animation)
{
    // Not pretty but there's no support for function vars.
    .eval data = GetBigBossAnimationData(data, animation)
    .eval data = GetMiniBossAnimationData(data, animation)

    .return data
}

// Get range (in x) of a game specific animation.
.function GetGameAnimationRange(rangeX, animation)
{
    .eval rangeX = GetBigBossAnimationRange(rangeX, animation)
    .eval rangeX = GetMiniBossAnimationRange(rangeX, animation)

    .return rangeX
}

//
// Define Animations here and add them to list of all Animations.
//

.eval Animations.add(ClipAnimation("Circle (127, 127, 256), 12 spr, enemy1 lightblue", "Circle (127, 85, 256)","Enemy1LoopLightBlue", 12, 11))
.eval Animations.add(ClipAnimation(            "Spiral (768), 10 spr, enemy2 green",          "Spiral (768)",    "Enemy2LoopGreen", 10, 14))
.eval Animations.add(ClipAnimation(         "Spiral (768), 10 spr, enemy2 lightred",          "Spiral (768)", "Enemy2LoopLightRed", 10, 14))
.eval Animations.add(ClipAnimation(          "Spiral (768), 6 spr, enemy2 lightred",          "Spiral (768)", "Enemy2LoopLightRed",  6, 20))
.eval Animations.add(ClipAnimation("Circle (100, 90, 320), 11 spr, enemy1 lightred", "Circle (100, 90, 288)", "Enemy1LoopLightRed", 11, 11))
.eval Animations.add(ClipAnimation("Circle (100, 90, 320), 4 spr, enemy1 lightblue", "Circle (100, 90, 288)", "Enemy1LoopLightBlue", 4, 11))
.eval Animations.add(ClipAnimation(   "Circle (100, 90, 320), 11 spr, enemy1 green", "Circle (100, 90, 288)",    "Enemy1LoopGreen", 11, 11))

.eval Animations.add(FormationClipAnimation("Fixed circle (72, 64, 16), enemy1 lightblue", "Fixed circle (72, 64, 16)", "Enemy1LoopLightBlue", "Circle (8, 32, 128)"))
.eval Animations.add(FormationClipAnimation("LetterH", "LetterH", "BeaconLoopCyan",    "Circle (8, 32, 128)"))
.eval Animations.add(FormationClipAnimation("LetterE", "LetterE", "BeaconLoopLightRed","Circle (8, 32, 128)"))
.eval Animations.add(FormationClipAnimation("LetterL", "LetterL", "BeaconLoopGray",    "Circle (8, 32, 128)"))
.eval Animations.add(FormationClipAnimation("LetterO", "LetterO", "BeaconLoopPurple",  "Circle (8, 32, 128)"))

.eval Animations.add(MegaSpriteAnimation("BigBoss", "BigBoss", "Circle (8, 32, 128)"))
.eval Animations.add(MegaSpriteAnimation("MiniBoss", "MiniBoss", "Circle (8, 32, 128)"))
.eval Animations.add(BigBossAnimation("BigBossAI"))
.eval Animations.add(MiniBossAnimation("MiniBossAI", "Circle (64, 12, 128)"))

//
// Define Animations per level and add them to list of all Animations per level.
//

// Level 1.
{
    // Init list of all level Animations.
    .var levelAnimations = List()

    .eval levelAnimations.add(AnimationInstance("Circle (127, 127, 256), 12 spr, enemy1 lightblue", 0, 0, 0, 0))
    .eval levelAnimations.add(AnimationInstance("Spiral (768), 10 spr, enemy2 green", 616, 0, 0, 0))
    .eval levelAnimations.add(AnimationInstance("Circle (100, 90, 320), 11 spr, enemy1 green", 1112, 0, 2, 0))
    .eval levelAnimations.add(AnimationInstance("Circle (100, 90, 320), 11 spr, enemy1 lightred", 1112, 0, 0, kFlipY))

    .eval levelAnimations.add(AnimationInstance("LetterH", 1600, 0, 0, 0))
    .eval levelAnimations.add(AnimationInstance("LetterE", 1766, 0, 0, 16))
    .eval levelAnimations.add(AnimationInstance("LetterL", 1932, 0, 0, 32))
    .eval levelAnimations.add(AnimationInstance("LetterL", 2098, 0, 0, 48))
    .eval levelAnimations.add(AnimationInstance("LetterO", 2264, 0, 0, 64))

    .eval levelAnimations.add(AnimationInstance("BigBossAI", 2722, 0, 0, 0))

    .eval levelAnimations.add(AnimationInstance("MiniBossAI", 3312,  10, 2,  0))
    .eval levelAnimations.add(AnimationInstance("MiniBossAI", 3312, 104, 2, 64))

    // Add list of level animations to list of all levels' animations.
    .eval AnimationsPerLevel.add(levelAnimations)
}

// Level 2.
{
    // Init list of all level Animations.
    .var levelAnimations = List()

    .eval levelAnimations.add(AnimationInstance("MiniBossAI", 240,  10, 2,  0))
    .eval levelAnimations.add(AnimationInstance("MiniBossAI", 240, 104, 2, 64))
/*    
    .eval levelAnimations.add(AnimationInstance("Circle (100, 90, 320), 4 spr, enemy1 lightblue", 0, 0, 2, kFlipY))
    .eval levelAnimations.add(AnimationInstance("Spiral (768), 6 spr, enemy2 lightred", 228, -16, 2, 0))
    .eval levelAnimations.add(AnimationInstance("Circle (100, 90, 320), 11 spr, enemy1 green", 536, 0, 2, 0))
    .eval levelAnimations.add(AnimationInstance("LetterH", 880, 16, 2, 0))
*/
    // Add list of level animations to list of all levels' animations.
    .eval AnimationsPerLevel.add(levelAnimations)
}
