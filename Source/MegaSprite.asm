/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

//
// Mega sprite = set of sprite positions, associated sprite pointers and color.
//

// List of all MegaSprites.
.var AllMegaSprites = List()

// Mapping from MegaSprite name to index.
.var MegaSpriteIndexByName = Hashtable()
.var MegaSpriteByName = Hashtable()

// MegaSprite = { name, sprites }
.struct MegaSprite { name, sprites, color }
.struct Sprite { posX, posY, pointer }

// Return range of positions x in MegaSprite.
.function MegaSpriteRange(megaSprite)
{
    .var minX = 255
    .var maxX = 0             
    .var sprites = megaSprite.sprites

    .for (var i = 0; i < sprites.size(); i++)
    {
        .var x = sprites.get(i).posX
        .eval minX = x < minX ? x : minX;
        .eval maxX = x > maxX ? x : maxX;
    }

   .return PositionRange(minX, maxX)
}

.function MegaSpriteBoundsX(megaSprite)
{
    .return MegaSpriteRange(megaSprite)
}

.function MegaSpriteBoundsY(megaSprite)
{
    .var minY = 255
    .var maxY = 0             
    .var sprites = megaSprite.sprites

    .for (var i = 0; i < sprites.size(); i++)
    {
        .var y = sprites.get(i).posY
        .eval minY = y < minY ? y : minY;
        .eval maxY = y > maxY ? y : maxY;
    }

   .return PositionRange(minY, maxY)
}

.function GetMegaSpriteByName(name)
{
    .if (!MegaSpriteByName.containsKey(name))
    {
        .error "Missing MegaSprite: " + name
    }

    .return MegaSpriteByName.get(name)
}

.function GetMegaSpriteIndexByName(name)
{
    .if (!MegaSpriteIndexByName.containsKey(name))
    {
        .error "Missing MegaSprite: " + name
    }

    .return MegaSpriteIndexByName.get(name)
}

//

#import "GameMegaSprite.asm"

//

.if (AllMegaSprites.size() > 256)
{
    .error "Too many MegaSprites (max 256): " + AllMegaSprites.size()
}

// Init mapping from MegaSprite name to index.
.for (var i = 0; i < AllMegaSprites.size(); i++)
{
    .var MegaSprite = AllMegaSprites.get(i);
    .eval MegaSpriteIndexByName.put(MegaSprite.name, i)
    .eval MegaSpriteByName.put(MegaSprite.name, MegaSprite)
}

//

.filenamespace MegaSprite

.segment Code "MegaSprite const data"

// MegaSprite data.
.enum { kColor }
.enum { kPointer, kPosY, kPosX, kSpriteSize }

.var AllMegaSpriteStartAddresses = List()
.for (var j = 0; j < AllMegaSprites.size(); j++)
{
    // Keep start address of this MegaSprite data.
    .eval AllMegaSpriteStartAddresses.add(*)

    .var megaSprite = AllMegaSprites.get(j)
    .var sprites = megaSprite.sprites
    .var len = sprites.size()

    // Sort sprites in descending order (they are added in reverse order at run-time).
    .for (var i = 0; i < len - 1; i++)
    {
        .var minY = sprites.get(i).posY
      
        .for (var j = i + 1; j < len; j++)
        {
            .var y = sprites.get(j).posY
            .if (y < minY)
            {
                .var sprite = sprites.get(i)
                .eval sprites.set(i, sprites.get(j))
                .eval sprites.set(j, sprites)
                .eval minY = y
            }
        }
    }
    .eval sprites.reverse()

    // kColor.
    .byte megaSprite.color

    // Array of positions and pointers.
    .for (var i = 0; i < len; i++)
    {  
        .var sprite = sprites.get(i)

        // kPointer, kPosY, kPosX
        .byte sprite.pointer + kSpriteBaseFrame, sprite.posY, sprite.posX // Reverse order because of how it's accessed at run-time.
    }   
}

// Keep end address of last MegaSprite's data.
.eval AllMegaSpriteStartAddresses.add(*)

// Array of start addresses of each MegaSprite's data.
DataLo:
.for (var i = 0; i < AllMegaSpriteStartAddresses.size(); i++)
{
    .byte <AllMegaSpriteStartAddresses.get(i)
}

DataHi:
.for (var i = 0; i < AllMegaSpriteStartAddresses.size(); i++)
{
    .byte >AllMegaSpriteStartAddresses.get(i)
}

// End address of each MegaSprite data.
.label DataEndLo = DataLo + 1
.label DataEndHi = DataHi + 1
