/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

//
// PositionList = list of positions.
//

// List of all PositionLists.
.var AllPositionLists = List()

// Mapping from PositionList name to index.
.var PositionListIndexByName = Hashtable()
.var PositionListByName = Hashtable()

// PositionList = { name, positions }
.struct PositionList { name, positions }

// Create a PositionList based on character data (i.e. grid).
.function PositionsFromCharData(bits, spacingX, spacingY, slantingX)
{
    .var positions = List()
    .var numRows = bits.size()

    .for (var j = 0; j < numRows; j++)
    {
        .var rowBits = bits.get(j)
        .var offsetX = (numRows - 1 - j) * slantingX

        .for (var i = 0; i < 8; i++)
        {
            .if ((rowBits & (128 >> i)) != 0)
            {
                .var x = i * spacingX + offsetX
                .var y = j * spacingY

                .eval positions.add(Position(x,y))
            }
        }
    }

   .return positions
}

// Return range of positions x in PositionList.
.function PositionListRange(positionList)
{
    .var minX = 255
    .var maxX = 0             
    .var positions = positionList.positions

    .for (var i = 0; i < positions.size(); i++)
    {
        .var x = positions.get(i).x
        .eval minX = x < minX ? x : minX;
        .eval maxX = x > maxX ? x : maxX;
    }

   .return PositionRange(minX, maxX)
}

.function GetPositionListByName(name)
{
    .if (!PositionListByName.containsKey(name))
    {
        .error "Missing PositionList: " + name
    }

    .return PositionListByName.get(name)
}

.function GetPositionListIndexByName(name)
{
    .if (!PositionListIndexByName.containsKey(name))
    {
        .error "Missing PositionList: " + name
    }

    .return PositionListIndexByName.get(name)
}

//

#import "GamePositionList.asm"

//

.if (AllPositionLists.size() > 256)
{
    .error "Too many PositionLists (max 256): " + AllPositionLists.size()
}

// Init mapping from PositionList name to index.
.for (var i = 0; i < AllPositionLists.size(); i++)
{
    .var positionList = AllPositionLists.get(i);
    .eval PositionListIndexByName.put(positionList.name, i)
    .eval PositionListByName.put(positionList.name, positionList)
}

//

.filenamespace PositionList

.segment Code "PositionList const data"

.const kMaxPosX = 254 // 255 is needed for visibility culling. 
.label kPositionListFrameSize = 2
.label kPositionListHeaderSize = 3

// PositionList data (positions).
//.enum { kFlipXConstant, kFlipYConstant, kPositions }
.enum { kPosY, kPosX }

.var AllPositionListStartAddresses = List()
.for (var j = 0; j < AllPositionLists.size(); j++)
{
    // Keep start address of this PositionList data.
    .eval AllPositionListStartAddresses.add(*)

    .var positionList = AllPositionLists.get(j)
    .var positions = positionList.positions
    .var len = positions.size()

    // Sort positions in descending order (they are added in reverse order at run-time).
    .for (var i = 0; i < len - 1; i++)
    {
        .var minY = positions.get(i).y
      
        .for (var j = i + 1; j < len; j++)
        {
            .var y = positions.get(j).y
            .if (y < minY)
            {
                .var position = positions.get(i)
                .eval positions.set(i, positions.get(j))
                .eval positions.set(j, position)
                .eval minY = y
            }
        }
    }
    .eval positions.reverse()

    // kPositions

    // Array of positions.
    .for (var i = 0; i < len; i++)
    {  
        .var position = positions.get(i)

        // kPosY, kPosX
        .byte position.y, position.x // Reverse order because of how it's accessed at run-time.
    }   
}

// Keep end address of last PositionList's data.
.eval AllPositionListStartAddresses.add(*)

// Array of start addresses of each PositionList's data.
ListsLo:
.for (var i = 0; i < AllPositionListStartAddresses.size(); i++)
{
    .byte <AllPositionListStartAddresses.get(i)
}

ListsHi:
.for (var i = 0; i < AllPositionListStartAddresses.size(); i++)
{
    .byte >AllPositionListStartAddresses.get(i)
}

// End address of each PositionList data.
.label ListsEndLo = ListsLo + 1
.label ListsEndHi = ListsHi + 1
