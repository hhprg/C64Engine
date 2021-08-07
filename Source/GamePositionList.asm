//
// Define PositionLists here and add them to list of all PositionLists.
//

{
    // Define keyframes.
    .var positions = List()  
    .for (var i = 0; i < 16; i++)  
    {  
        .var angle = toRadians(i * 360 / 16)  
        .var rx = 72
        .var ry = 64

        .eval positions.add(Position(round(rx * (cos(angle) + 1)), round(ry * (sin(angle) + 1))))
    }

    // Add to list of all PositionLists.
    .eval AllPositionLists.add(PositionList("Fixed circle (72, 64, 16)", positions))
}

.eval AllPositionLists.add(PositionList("LetterH", PositionsFromCharData(List().add(%10100000, %10100000, %11100000, %10100000, %10100000), 34, 28, 8)))
.eval AllPositionLists.add(PositionList("LetterE", PositionsFromCharData(List().add(%11100000, %10000000, %11000000, %10000000, %11100000), 34, 28, 8)))
.eval AllPositionLists.add(PositionList("LetterL", PositionsFromCharData(List().add(%10000000, %10000000, %10000000, %10000000, %11100000), 34, 28, 8)))
.eval AllPositionLists.add(PositionList("LetterO", PositionsFromCharData(List().add(%01000000, %10100000, %10100000, %10100000, %01000000), 34, 28, 8)))
