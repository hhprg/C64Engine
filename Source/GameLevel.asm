/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

// Per level.

// Todo: Sprite colors per level?

// Level 1.
{
    .const kTileMapData = CharTileMap.TileMapData + 0 * CharTileMap.kBytesPerTileMapColumn

    .const kTileMapWidth = CharTileMap.kTileMapWidth
    .const kStartPos = 0 // Start pos in chars.
    .const kMaxPos = (kTileMapWidth * CharTileMap.kTileSize - kNumVisibleColumns)
    .const kPlayerStartPosX = kStartPos * 8 + 150
    .const kPlayerStartPosY = kSpriteStartY + 100
    .const kBackgroundColor = CharTileMap.kBackgroundColor
    .const kMultiColor1 = CharTileMap.kMulticolor1
    .const kMultiColor2 = CharTileMap.kMulticolor2

    .eval AllLevels.add(Level(
        kTileMapData, kTileMapWidth,
        kStartPos, kMaxPos,
        kPlayerStartPosX, kPlayerStartPosY,
        kBackgroundColor, kMultiColor1, kMultiColor2))
}

// Level 2.
{
    .const kStartTileMapColumn = CharTileMap.kTileMapWidth - 27

    .const kTileMapData = CharTileMap.TileMapData + kStartTileMapColumn * CharTileMap.kBytesPerTileMapColumn

    .const kTileMapWidth = CharTileMap.kTileMapWidth - kStartTileMapColumn
    .const kStartPos = 0 // Start pos in chars.
    .const kMaxPos = (kTileMapWidth * CharTileMap.kTileSize - kNumVisibleColumns)
    .const kPlayerStartPosX = kStartPos * 8 + 150
    .const kPlayerStartPosY = kSpriteStartY + 100
    .const kBackgroundColor = CharTileMap.kBackgroundColor
    .const kMultiColor1 = DARK_GRAY
    .const kMultiColor2 = WHITE

    .eval AllLevels.add(Level(
        kTileMapData, kTileMapWidth,
        kStartPos, kMaxPos,
        kPlayerStartPosX, kPlayerStartPosY,
        kBackgroundColor, kMultiColor1, kMultiColor2))
}
