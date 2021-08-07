/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

// List of all defined SpriteClipKeys.
.var AllSpriteClipKeys = List()

// List of all defined SpriteClips.
.var AllSpriteClips = List()

// Mapping from SpriteClipKeys name to index.
.var SpriteClipKeysIndexByName = Hashtable()

// Mapping from SpriteClip name to index and SpriteClip.
.var SpriteClipIndexByName = Hashtable()
.var SpriteClipByName = Hashtable()

// SpriteClipKeys = list of sprite frames and their (constant) spacing in time.
// Todo: Support non-constant hold times?
.struct SpriteClipKeys { name, holdTime, relFrames }

// SpriteClip = {name, SpriteClipKeys name, sprite base frame, color}
.struct SpriteClip { name, clipKeysName, base, color }

//

.function GetSpriteClipByName(name)
{
    .if (!SpriteClipByName.containsKey(name))
    {
        .error "Missing SpriteClip: " + name
    }

    .return SpriteClipByName.get(name)
}

.function GetSpriteClipIndexByName(name)
{
    .if (!SpriteClipIndexByName.containsKey(name))
    {
        .error "Missing SpriteClip: " + name
    }

    .return SpriteClipIndexByName.get(name)
}

//

#import "GameSpriteClip.asm"

//

.if (AllSpriteClipKeys.size() > 256)
{
    .error "Too many SpriteClipKeys (max 256): " + AllSpriteClipKeys.size()
}

// Todo: Support more than 256?
.if (AllSpriteClips.size() > 256)
{
    .error "Too many SpriteClips (max 256): " + AllSpriteClips.size()
}

// Init mapping from SpriteClipKeys name to index.
.for (var i = 0; i < AllSpriteClipKeys.size(); i++)
{
    .eval SpriteClipKeysIndexByName.put(AllSpriteClipKeys.get(i).name, i)
}

// Init mapping from SpriteClip name to index and SpriteClip.
.for (var i = 0; i < AllSpriteClips.size(); i++)
{
    .var clip = AllSpriteClips.get(i)
    .eval SpriteClipIndexByName.put(clip.name, i)
    .eval SpriteClipByName.put(clip.name, clip)
}

//

.filenamespace SpriteClip

//

.segment Code "SpriteClip const data"

.enum { kClipKeysIndex, kBaseFrame, kColor } // 3 bytes per SpriteClip.
.enum { kLen, kHoldTime } // 2 bytes SpriteClipKeys header.

.label kClipKeysHeaderSize = 2
.label kClipKeysFrameSize = 1
.label kClipSize = 3

// Array of SpriteClips.
Clips:
.for (var i = 0; i < AllSpriteClips.size(); i++)
{
    .var clip = AllSpriteClips.get(i)
    .var clipKeysIndex = SpriteClipKeysIndexByName.get(clip.clipKeysName)

    .byte clipKeysIndex, clip.color, kSpriteBaseFrame + clip.base
}

// SpriteClipKeys data (relative sprite frames).
.var AllClipKeysStartAddresses = List()
.for (var i = 0; i < AllSpriteClipKeys.size(); i++)
{
    .var clipKeys = AllSpriteClipKeys.get(i)
    .var frames = clipKeys.relFrames
    .var len = frames.size()
    .var maxLen = 255 - kClipKeysHeaderSize

    .if (len > maxLen)
    {
        .error "Too many SpriteClipKeys frames (max " + maxLen + ") in '" + clipKeys.name + "': " + len
    }

    // Keep start address of this SpriteClipKeys' data.
    .eval AllClipKeysStartAddresses.add(*)

    // Header (kLen, kHoldTime)
    .byte len, clipKeys.holdTime

    // Array of frames.
    .for (var j = 0; j < len; j++)
    {
        .var frame = frames.get(j)
        .byte frame
    }
}

// Keep end address of last SpriteClipKeys' data.
.eval AllClipKeysStartAddresses.add(*)

// Array of start addresses of each SpriteClipKeys' data.
ClipKeysLo:
.for (var i = 0; i < AllSpriteClipKeys.size() + 1; i++)
{
    .byte <AllClipKeysStartAddresses.get(i)       
}

ClipKeysHi:
.for (var i = 0; i < AllSpriteClipKeys.size() + 1; i++)
{
    .byte >AllClipKeysStartAddresses.get(i)       
}
