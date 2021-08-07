/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.file [name="bin/Engine.prg", segments="Code,Sprites", allowOverlap]

//

.segment Code [start=$0840]
.segment Zeropage [start=$08, min=$08, max=$ff, virtual]
.segment BSS1 [start=$0200, min=$0200, max=$07ff, virtual]
.segment BSS2 [start=$b000, min=$b000, max=$bfff, virtual]
.segment Graphics [start=$c000, virtual]
.segment Sprites [start=$d000, min=$d000, max=$fff0]

.segment Zeropage
.label ZeropageBegin = *

.segment BSS1
.label BSS1Begin = *

.segment BSS2
.label BSS2Begin = *

//

.segment Sprites "Sprite const data"

.label kSpriteBaseFrame = (* & $3fff) / 64
.var Sprites = LoadBinary("../Assets/ArmalyteSprites.prg", BF_C64FILE)   
.fill Sprites.getSize(), Sprites.get(i)   

//

#import "Common.asm"

//

.segment Graphics "ScreenMem0"
.label Screen0Mem = *
.fill kScreenMemSize, 0

.segment Graphics "ScreenMem1"
.label Screen1Mem = *
.fill kScreenMemSize, 0
   
.segment Graphics "CharSetMem"
.label CharSetMem = *
.fill kCharDataSize, 0

.const kCharSetBits = ((>CharSetMem) & %00111000) >> 2
.const kScreen0AdrBits = (((>Screen0Mem) & %00111100) << 2) | kCharSetBits
.const kScreen1AdrBits = (((>Screen1Mem) & %00111100) << 2) | kCharSetBits

//

.segment Code "Main"

.namespace Main
{
#if DEBUG
    .var ShowRasterTime = true
#else
    .var ShowRasterTime = false
#endif // DEBUG

    Init:
    {
                    sei
                    cld
                    ldx #$ff
                    txs

                    // https://www.c64-wiki.com/index.php/Bankswitching
                    // http://www.harries.dk/files/C64MemoryMaps.pdf
                    // Page 264 in http://www.bombjack.org/commodore/commodore/C64_Programmer's_Reference_Guide.pdf

                    lda #%00110101  // RAM $a000-$bfff, IO $d000-$dfff, RAM $e000-$ffff
                    sta $01
                    lda $dd02       // Select bits 0-1 in $dd00 for output.
                    ora #%00000011
                    sta $dd02
                    lda $dd00       // Set VIC-II bank 3 ($c000-$ffff).
                    and #%11111100
                    ora #((>CharSetMem) >> 6) ^ 3
                    sta $dd00
                    lda #$7f
                    sta $dc0d       // Disable hardware timer interrupt.
                    lda #%00000001  // Enable raster compare IRQ.
                    sta $d01a
                    lda #%00011011  // 25 row display.
                    sta $d011
                    lda #%00010111
                    sta $d016
                    lda #kScreen0AdrBits
                    sta $d018
                    lda #$ff                
                    sta $d015       // Enable all hardware sprites.
                    sta $d01c       // All multicolor sprites.
                    lda #0
                    sta $d01b       // Sprite > foreground priority.
                    lda #kMainIRQRasterline
                    sta $d012
                    lda #WHITE
                    sta $d025
                    lda #DARK_GRAY
                    sta $d026

                    lda #>IRQHandler
                    sta $ffff
                    lda #<IRQHandler
                    sta $fffe
                    lda #>IRQHandler.NMIHandler
                    sta $fffb
                    lda #<IRQHandler.NMIHandler
                    sta $fffa

                    // Clear zeropage and BSS memory first!        
                    jsr Memory.Init

                    lda #0 // Start level.
                    sta.zp LevelData.zpCurrent
                    jsr CharTileMap.Init
                    jsr Scroll.Init
                    jsr Camera.Init
                    jsr SpriteClipAnimator.Init
                    jsr PositionClipAnimator.Init      
                    jsr AnimationTrigger.Init
                    jsr Multiplexer.Init
                    jsr Player.Init
                    cli
        Self:       jmp Self
    }
   
    // Re-entrant IRQ handler.
    IRQHandler:
    {
                    pha
                    txa
                    pha
                    tya
                    pha
                    cld

                    lda #%00000001 // Clear raster compare IRQ source
                    sta $d019

                    lda #$fa  // Move all sprites below bottom border.
                    sta $d001
                    sta $d003
                    sta $d005
                    sta $d007
                    sta $d009
                    sta $d00b
                    sta $d00d
                    sta $d00f

                    //lda #%00010011  // 24 row display to open border.
                    //sta $d011
                    lda #0
                    sta $d015
        .if (ShowRasterTime) 
        {
                    lda #0
                    sta $d020
        }
                    MultiplexerBeginFrame()
                    TimeUpdate()
                    InputUpdate()
                    jsr Camera.Update
                    CameraPostUpdate()              
                    jsr AnimationTrigger.Update

                    lda Animator.IsPreparingAnimation
                    beq !NotCritical+

                    // These subroutines are not re-entrant and are currently also running on background task.
                    // Save off used zeropage variables to avoid trashing them.
                    SpriteClipAnimatorPreUpdate()
                    jsr SpriteClipAnimator.Update
                    SpriteClipAnimatorPostUpdate()
                    PositionClipAnimatorPreUpdate()
                    jsr PositionClipAnimator.Update
                    PositionClipAnimatorPostUpdate()
                    jmp !AfterCritical+
        
        !NotCritical:
                    jsr SpriteClipAnimator.Update
                    jsr PositionClipAnimator.Update

        .if (ShowRasterTime) inc $d020
        
        !AfterCritical:
                    // First add sprites that are always on screen.
                    jsr Player.Update

                    lda Animator.IsPreparingAnimation
                    beq !NotCritical+

                    AnimatorPreUpdate()
                    jsr AnimationTrigger.UpdateActive
                    AnimatorPostUpdate()
                    jmp !AfterCritical+

        !NotCritical:
                    jsr AnimationTrigger.UpdateActive

        !AfterCritical:    
                    // Display front buffer (tables are in reverse order).
                    ldx Scroll.BackbufferIndex
                    lda ScreenAdrBits,x
                    sta $d018
                    lda ScreenMemHi,x
                    sta Multiplexer.IRQHandler.Add.ScreenMemHi
                    sta Multiplexer.EndFrame.Add.ScreenMemHi
               
        .if (ShowRasterTime) inc $d020
                    jsr Multiplexer.EndFrame

                    //lda #%00011011  // 25 row display.
                    //sta $d011
                    lda #$ff
                    sta $d015

                    lda Camera.FineScroll
                    ora #%00010000 // 38-column mode, enable multicolor 
                    sta $d016
               
        .if (ShowRasterTime)
        {
                    lda #14
                    sta $d020
        }
               
                    jsr Task.Update

                    pla
                    tay
                    pla
                    tax
                    pla
        NMIHandler: rti
    }
   
    // Reverse order because indexed with backbuffer index.
    ScreenAdrBits:
    .byte kScreen1AdrBits, kScreen0AdrBits

    ScreenMemHi:
    .byte >(Screen1Mem + $03f8), >(Screen0Mem + $03f8)
} // .namespace Main

//

#import "Memory.asm"
#import "Task.asm"
#import "Time.asm"
#import "Camera.asm"
#import "Input.asm"
#import "AnimationData.asm"
#import "AnimationTrigger.asm"
#import "Multiplexer.asm"
#import "CharTileMap.asm"
#import "LevelData.asm"
//#import "RLE.asm"
#import "Scroll.asm"
#import "ColorScroll.asm"
#import "Player.asm"
         
//

.segment Zeropage
.label ZeropageEnd = *

.segment BSS1
.label BSS1End = *

.segment BSS2
.label BSS2End = *
