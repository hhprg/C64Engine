/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

#importonce

//#define DEBUG
//#define COLOR_PER_TILE

.const kMainIRQRasterline = 250 - 21 + 3 // 250 - 1 to open border              

.const kJoystickUpBit = %00000001
.const kJoystickDownBit = %00000010
.const kJoystickLeftBit = %00000100
.const kJoystickRightBit = %00001000
.const kJoystickLeftOrRightBits = kJoystickLeftBit | kJoystickRightBit 
.const kJoystickUpOrDownBits = kJoystickUpBit | kJoystickDownBit 

.const kDefaultAdr = $BABE
.const kStackAdr = $0100

.const kUndefined = $ff       // Don't change, used with dec in code.
.const kUndefinedIndex = 0    // Don't change, used with beq in code.
.const kSpriteWidth = 24
.const kSpriteHeight = 21

.const kScreenWidthPixels = 320
.const kScreenHeightPixels = 200
.const kNumVisibleScreenPixels = kScreenWidthPixels - 16
 
.const kNumScreenRows = 25
.const kNumScreenColumns = 40
.const kNumVisibleColumns = 39 // Last column is never visible when scrolling.
.const kScreenMemSize = 1024
.const kCharDataSize = 256 * 8
.const kColorMem = $d800
.const kColorMask = %00001111

.const kSpriteStartX = 32 // Sprite x position at left screen border.
.const kSpriteStartY = 50 // Sprite y position at top screen border.
.const kSpriteStopY = kSpriteStartY + kScreenHeightPixels - kSpriteHeight 

// Directions.
.enum {kRight=$ff, kNone=0, kLeft=1} // Don't change order! Todo: Switch left and right to make it intuitive.

// Functions.
.function Frac(val)
{
    .return floor((val - floor(val)) * 256)
}

.function RoundToZero(val)
{
    .if (val < 0)
    {
        .return ceil(val)
    } 
    else
    {
        .return floor(val)
    }
}

// Macros.
.macro DebugHang()
{
#if DEBUG
                inc $d021
                jmp *
#endif // DEBUF
}

.macro AddByteOffset(src, offset, dst) 
{ 
                lda src 
                adc offset 
                sta dst 
                lda src + 1 
                adc #0 
                sta dst + 1 
} 

.macro AddByteOffsetLoHi(src, offset, dstlo, dsthi) 
{ 
                lda src 
                adc offset 
                sta dstlo 
                lda src + 1 
                adc #0 
                sta dsthi 
} 

.macro AddByteOffsetImm(src, offset, dst) 
{ 
                lda src 
                adc #offset 
                sta dst 
                lda src + 1 
                adc #0 
                sta dst + 1 
} 
