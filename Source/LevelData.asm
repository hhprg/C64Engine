/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.var AllLevels = List()
.struct Level { tileMapData, tileMapWidth, startPos, maxPos, playerStartPosX, playerStartPosY, backgroundColor, multiColor1, multiColor2 }

.filenamespace LevelData

//

.segment Zeropage "LevelData zeropage data"

zpCurrent:
.fill 1, 0

//

.segment Code "LevelData const data"

//

#import "GameLevel.asm"

//

.const kNumLevels = AllLevels.size()

// Arrays of per level data.
BackgroundColor: // $d021   
.for (var i = 0; i < kNumLevels; i++)
{
    .byte AllLevels.get(i).backgroundColor
}

MultiColor1: // $d022
.for (var i = 0; i < kNumLevels; i++)
{
    .byte AllLevels.get(i).multiColor1
}

MultiColor2: // $d023
.for (var i = 0; i < kNumLevels; i++)
{
    .byte AllLevels.get(i).multiColor2
}

TileMapDataLo:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte <AllLevels.get(i).tileMapData
}
TileMapDataHi:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte >AllLevels.get(i).tileMapData
}

TileMapWidthLo:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte <AllLevels.get(i).tileMapWidth
}
TileMapWidthHi:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte >AllLevels.get(i).tileMapWidth
}

StartTileCharIndex:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte mod(AllLevels.get(i).startPos, CharTileMap.kTileSize)
}

StartTileMapIndexLo:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte <(AllLevels.get(i).startPos / CharTileMap.kTileSize)
}
StartTileMapIndexHi:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte >(AllLevels.get(i).startPos / CharTileMap.kTileSize)
}

// Start position in pixels.
StartPosLo:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte <(AllLevels.get(i).startPos * 8)
}
StartPosHi:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte >(AllLevels.get(i).startPos * 8)
}

// Max position in pixels.   
MaxPosLo:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte <(AllLevels.get(i).maxPos * 8)
}
MaxPosHi:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte >(AllLevels.get(i).maxPos * 8)
}

PlayerStartPosXLo:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte <AllLevels.get(i).playerStartPosX
}
PlayerStartPosXHi:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte >AllLevels.get(i).playerStartPosX
}

PlayerStartPosY:
.for (var i = 0; i < kNumLevels; i++)
{
    .byte AllLevels.get(i).playerStartPosY
}
