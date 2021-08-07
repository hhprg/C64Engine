/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

//
// PositionClip = list of position key frames and flip xy flags.
//

// List of all PositionClips.
.var AllPositionClips = List()

// Mapping from PositionClip name to index.
.var PositionClipIndexByName = Hashtable()
.var PositionClipByName = Hashtable()

// PositionClip = list of position keyframes.
.struct PositionClip { name, keyframes }

// Position keyframe.
.struct PosKey { time, x, y }
.struct Position { x, y }
.struct PositionRange { minX, maxX }

.const kMaxPosX = 254 // 255 is needed for visibility culling. 

// Return range of positions x in PositionList.
.function PositionClipRange(positionClip)
{
    .var minX = 255
    .var maxX = 0             
    .var keyframes = positionClip.keyframes
 
    .for (var i = 0; i < keyframes.size(); i++)
    {
        .var x = keyframes.get(i).x
        .eval minX = x < minX ? x : minX;
        .eval maxX = x > maxX ? x : maxX;
    }

   .return PositionRange(minX, maxX)
}

.function GetPositionClipByName(name)
{
    .if (!PositionClipByName.containsKey(name))
    {
        .error "Missing PositionClip: " + name
    }

    .return PositionClipByName.get(name)
}

.function GetPositionClipIndexByName(name)
{
    .if (!PositionClipIndexByName.containsKey(name))
    {
        .error "Missing PositionClip: " + name
    }

    .return PositionClipIndexByName.get(name)
}

//

#import "GamePositionClip.asm"

//

.if (AllPositionClips.size() > 256)
{
    .error "Too many PositionClips (max 256): " + AllPositionClips.size()
}

// Init mapping from PositionClip name to index.
.for (var i = 0; i < AllPositionClips.size(); i++)
{
    .var positionClip = AllPositionClips.get(i);
    .eval PositionClipIndexByName.put(positionClip.name, i)
    .eval PositionClipByName.put(positionClip.name, positionClip)
}

//

.filenamespace PositionClip

.segment Code "PositionClip const data"

.label kClipKeyframeSize = 3
.label kClipHeaderSize = 4

// PositionClipKeys data (position keyframes).
.enum { kStartX, kStartY, kFlipXConstant, kFlipYConstant, kKeyframes }
.enum { kDuration, kVelX, kVelY }

.var AllClipStartAddresses = List()
.for (var j = 0; j < AllPositionClips.size(); j++)
{
    // Keep start address of this PositionClip's data.
    .eval AllClipStartAddresses.add(*)

    .var clip = AllPositionClips.get(j)
    .var keyframes = clip.keyframes
    .var len = keyframes.size() - 1 // Number of intervals. 
    .var velXCombined = List()
    .var velYCombined = List()
    .var startX = max(0, min(keyframes.get(0).x, kMaxPosX))
    .var startY = keyframes.get(0).y

    // kStartX, kStartY
    .byte startX, startY

    .var minX = startX
    .var maxX = minX
    .var minY = startY
    .var maxY = minY

    .for (var i = 0; i < len; i++)
    {
        .var next = keyframes.get(i + 1)
        .var nextX = max(0, min(next.x, kMaxPosX))
        .var dt = min(255, next.time - keyframes.get(i).time)
        .var dxdt = RoundToZero([[nextX - startX] / dt] * 32)
        .var dydt = RoundToZero([[next.y - startY] / dt] * 32)

        .if ((dxdt > 127) || (dxdt < -128))
            .error "Velocity x out of range: " + dxdt + "."
        .if ((dydt > 127) || (dydt < -128))
            .error "Velocity y out of range: " + dydt + "."

        .eval velXCombined.add(<dxdt)
        .eval velYCombined.add(<dydt)

        .eval startX = startX + dt * (dxdt / 32)
        .eval startY = startY + dt * (dydt / 32)

        .eval minX = min(minX, startX)
        .eval maxX = max(maxX, startX)
        .eval minY = min(minY, startY)
        .eval maxY = max(maxY, startY)
    }

    // Flip: x' = maxX - (x - minX) = maxX + minX - x
    //       x' = (maxX + minX) / 2  - (x - (maxX + minX) / 2) = maxX + minX - x

    // kFlipXConstant, kFlipYConstant
    .byte RoundToZero((maxX + minX + 1) / 2)
    .byte RoundToZero((maxY + minY + 1) / 2)

    // kKeyframes

    // Array of keyframes.
    .for (var i = 0; i < len; i++)
    {  
        // Duration.
        .var dt = min(255, keyframes.get(i + 1).time - keyframes.get(i).time)

        // kDuration 
        .byte dt

        // kVelX
        .var velX = velXCombined.get(i) 
        .byte velX

        // kVelY
        .var velY = velYCombined.get(i) 
        .byte velY
    }   
}

// Keep end address of last PositionClip's data.
.eval AllClipStartAddresses.add(*)

// Array of start addresses of each PositionClip's data.
ClipsLo:
.for (var i = 0; i < AllClipStartAddresses.size(); i++)
{
    .byte <AllClipStartAddresses.get(i)
}

ClipsHi:
.for (var i = 0; i < AllClipStartAddresses.size(); i++)
{
    .byte >AllClipStartAddresses.get(i)
}

// End address of each PositionClip's data.
.label ClipsEndLo = ClipsLo + 1
.label ClipsEndHi = ClipsHi + 1
