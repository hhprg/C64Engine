//
// Define MegaSprites here and add them to list of all MegaSprites.
//

{
    .var sprites = List()  

    .eval sprites.add(Sprite( 0,  0,149), Sprite(24,  0,150), Sprite(48,  0,151))
    .eval sprites.add(Sprite(48, 21,161), Sprite(72, 21,162))
    .eval sprites.add(Sprite(72, 42,163), Sprite(96, 42,164))
    .eval sprites.add(Sprite(72, 63,165), Sprite(96, 63,166))
    .eval sprites.add(Sprite(48, 84,167), Sprite(72, 84,168))
    .eval sprites.add(Sprite( 0,105,157), Sprite(24,105,158), Sprite(48,105,169))

    // Add to list of all MegaSprites.
    .eval AllMegaSprites.add(MegaSprite("BigBoss", sprites, GRAY))
}

{
    .var sprites = List()  

    .eval sprites.add(Sprite( 0,  0,149), Sprite(24,  0,150), Sprite(48,  0,151))
    .eval sprites.add(Sprite(48, 21,156))
    .eval sprites.add(Sprite( 0, 42,157), Sprite(24, 42,158), Sprite(48, 42,169))

    // Add to list of all MegaSprites.
    .eval AllMegaSprites.add(MegaSprite("MiniBoss", sprites, GRAY))
}
