//
// Define PositionClips here and add them to list of all PositionClips.
//

{
    // Define keyframes.
    .var keyframes = List()  
    .for (var i = 0; i < 33; i++)  
    {  
        .var angle = toRadians(i * 360 / 32)  

        .eval keyframes.add(PosKey(i * 8, round(127 * (cos(angle) + 1)), round(85 * (sin(angle) + 1))))
    }

    // Add to list of all PositionClips.
    .eval AllPositionClips.add(PositionClip("Circle (127, 85, 256)", keyframes))
}

{
    // Define keyframes.
    .var keyframes = List()  
    .for (var i = 0; i < 33; i++)  
    {  
        .var angle = toRadians(i * 360 / 32)  
        .eval keyframes.add(PosKey(i * 9, round(100 * (cos(angle) + 1)), round(90 * (sin(angle) + 1))))
    }

    // Add to list of all PositionClips.
    .eval AllPositionClips.add(PositionClip("Circle (100, 90, 288)", keyframes))
}

{
    // Define keyframes.
    .var keyframes = List()  
    .for (var i = 0; i < 17; i++)  
    {  
        .var angle = toRadians(i * 360 / 16)  
        .eval keyframes.add(PosKey(i * 8, round(8 * (cos(angle) + 1)), round(32 * (sin(angle) + 1))))
    }

    // Add to list of all PositionClips.
    .eval AllPositionClips.add(PositionClip("Circle (8, 32, 128)", keyframes))
}

{
    // Define keyframes.
    .var keyframes = List()  
    .for (var i = 0; i < 17; i++)  
    {  
        .var angle = toRadians(i * 360 / 16)  
        .eval keyframes.add(PosKey(i * 12, round(64 * (cos(angle) + 1)), round(12 * (sin(2 * angle) + 1))))
    }

    // Add to list of all PositionClips.
    .eval AllPositionClips.add(PositionClip("Circle (64, 12, 128)", keyframes))
}

{
    // Define keyframes.
    .var keyframes = List()  
    {  
        .var positions = List()
        .var angle = 0  
        .var r0 = floor((200 - 21 - 40) / 1.75)
        .var r1 = r0 * 0.5
        .var cx = r0
        .var cy = 200 - 21 - r0

        .for (var i = 0; i < 33; i++)  
        {  
            .var a0 = toRadians(i * 360.0 / (32.0 / 1))  
            .var a1 = 2 * a0

            .var tween = i / 32.0
            .var r = r0 + tween * (r1 - r0)
            .var a = a0 + tween * (a1 - a0)

            .eval positions.add(Position(-r * sin(a), r * cos(a)))
        }
      
        .for (var i = 0; i < 32; i++)  
        {  
            .var position = positions.get(31 - i)   

            .eval positions.add(Position(-position.x, position.y))
        }
      
        .for (var i = 0; i < 65; i++)
        {
            .var position = positions.get(i)   
            .eval keyframes.add(PosKey(i * 12, round(1.2 * (position.x + cx)), round(position.y + cy)))
        }
    }  

    // Add to list of all PositionClips.
    .eval AllPositionClips.add(PositionClip("Spiral (768)", keyframes))
}
