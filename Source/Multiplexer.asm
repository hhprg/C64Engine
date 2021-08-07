/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Multiplexer 

//

.const kYSpacing = kSpriteHeight + 4 // Min y-spacing between same hardware sprites.
.label kMaxVirSprites = 24 // Max number of virtual sprites.

.segment Zeropage "Multiplexer zeropage data"

//.fill 1, 0 // kMaxVirSprites byte, needed by sort code.
zpSortedVirSprites:
.fill kMaxVirSprites, 0

zpSrcIndex:
.fill 1, 0

zpIRQSpriteIndex:
.fill 1, 0

zpVirSpritePosY:
.fill kMaxVirSprites, 0
//.fill 1, 0 // Zero byte, needed by sort code.

zpHardwareSpritesEndY:
.fill 8, 0

zpHardwareSpritesStartY:
.fill 8, 0

zpHardwareSprites:
.fill kMaxVirSprites, 0

//

.segment Code "Multiplexer code"

#if DEBUG
.var ShowIRQRasterTime = true
.var ShowRasterTime = true
#else   
.var ShowIRQRasterTime = false
.var ShowRasterTime = false
#endif // DEBUG   

// Priorities: Layer 0 > Layer 1 > Layer 2

.macro @MultiplexerBeginFrame()
{
                lda #0
                sta Multiplexer.NumVirSprites
                sta Multiplexer.NumVirSpritesPerLayer         
                sta Multiplexer.NumVirSpritesPerLayer + 1         
                sta Multiplexer.NumVirSpritesPerLayer + 2         
}

// x = vir sprite index
// y = hardware sprite index
.macro SetSprite()
{
                lda zpVirSpritePosY,x
                adc #kSpriteHeight // c = 0 assumed here
                sta zpHardwareSpritesEndY,y

                lda VirSpriteColorLayers,x
                sta $d027,y
                lda VirSpritePointers,x
    .label ScreenMemHi = *+2               
                sta Screen0Mem + $03f8,y

                tya
                asl
                tay
                lda zpVirSpritePosY,x   // Todo: $d001 first since less timing dependent?
                sta $d001,y

                lda VirSpritePosXLo,x       
                sta $d000,y
}
      
//

// Non-re-entrant IRQ handler.         
IRQHandler:
{           
                sta RegA
                stx RegX
                sty RegY
                cld

                lda #%00000001 // Clear raster compare IRQ source
                sta $d019

    .if (ShowIRQRasterTime) inc $d020

                clc
    Loop:       ldy zpIRQSpriteIndex
                ldx zpSortedVirSprites,y
                lda zpHardwareSprites,y
                tay

    Add:        SetSprite()   
                lda VirSpritePosXHi,x
                beq ClearMSB
                lda $d010
                ora SetBit,y
                bne UpdateMSB // bra
    ClearMSB:   lda $d010
                and ClearBit,y
    UpdateMSB:  sta $d010
   
                ldy zpIRQSpriteIndex
                iny
                cpy NumSprites:#0
                bcs Done

                sty zpIRQSpriteIndex

                ldx zpHardwareSprites,y
                lda zpHardwareSpritesEndY,x // c = 0
                //sec
                sbc $d012
                bcc Loop // Raster already past next hardware sprite end line so okay to re-use it.

                cmp #2   // Make sure next raster IRQ is at least 2 raster lines away.
                lda zpHardwareSpritesEndY,x
                bcs NextIRQ 
                adc #2
    NextIRQ:    sta $d012      
   
    .if (ShowIRQRasterTime) dec $d020

                // Todo: Open top/bottom border IRQ handler?

                lda RegA:#0
                ldx RegX:#0
                ldy RegY:#0
                rti

    Done:       lda #>Main.IRQHandler
                sta $ffff
                lda #<Main.IRQHandler
                sta $fffe
                lda #kMainIRQRasterline
                bne NextIRQ // bra                  
}

//

Init:
{
                ldx #kMaxVirSprites
                stx EndFrame.UsedLastFrame
                //stx zpSortedVirSprites-1 
    Loop:       dex
                txa
                sta zpSortedVirSprites,x
                bne Loop
                rts
}

//

EndFrame:
{
                // Move any unused vir sprites to max y.
                lax NumVirSprites
                cmp UsedLastFrame
                bcs AllSet
                ldy #$ff
    Set:        sty zpVirSpritePosY,x         
                inx
                cpx UsedLastFrame:#0
                bcc Set
    AllSet:     sta UsedLastFrame
                tax
                bne Sprites
                rts
    Sprites:
    //.if (ShowRasterTime) inc $d020 

                jsr SortVirSprites
    .if (ShowRasterTime) inc $d020

                // All vir sprites in one layer?
                lda NumVirSprites
                cmp NumVirSpritesPerLayer + 0
                beq OneLayer
                cmp NumVirSpritesPerLayer + 1
                beq OneLayer
                cmp NumVirSpritesPerLayer + 2
                bne NotOneLayer

    OneLayer:   // Trivial alloc if all sprites in single layer.
                jsr AllocHardwareSpritesSingleLayer
                jmp Done

    NotOneLayer:lda NumVirSpritesPerLayer + 2
                bne UseLayer2

                // Use layer 0 and 1.
                jsr AllocHardwareSpritesLayer01
                jmp Done

    UseLayer2:  lda NumVirSpritesPerLayer + 0
                bne UseAllLayers

                // Use layer 1 and 2.
                jsr AllocHardwareSpritesLayer12
                jmp Done

    UseAllLayers:               
                // Use layer 0, 1(?) and 2.
                jsr AllocHardwareSprites

    Done:        

    .if (ShowRasterTime) inc $d020
                // Setup IRQ.

                lda NumVirSprites
                sta NumSprites
                sta IRQHandler.NumSprites

                // Position vir sprites up to first hardware sprite re-use.
                ldy #0               
    .for (var i = 0; i < 8; i++)
                sty zpHardwareSpritesEndY + i 

                sty $d010
                clc               
    Loop:       sty zpIRQSpriteIndex
                ldx zpHardwareSprites,y
                lda zpHardwareSpritesEndY,x
                bne SpritesDone
                txa
                ldx zpSortedVirSprites,y
                tay
    Add:        SetSprite()

                lda VirSpritePosXHi,x
                beq NoMSB
                lda $d010
                ora SetBit,y
                sta $d010
    NoMSB:      ldy zpIRQSpriteIndex
                iny
                cpy NumSprites:#0
                bcc Loop
                rts // Positioned all vir sprites, no need for interrupt.
            
    SpritesDone:lda #>IRQHandler
                sta $ffff
                lda #<IRQHandler
                sta $fffe
               
                lda zpHardwareSpritesEndY,x
                bne SetRaster
                ldx zpSortedVirSprites,y
                lda zpVirSpritePosY,x
                sbc #2 // c = 0
    SetRaster:  sta $d012
                rts         
}

//

SortVirSprites:
{
                ldy #1
    Next:       ldx zpSortedVirSprites,y
                lda zpVirSpritePosY,x
                ldx zpSortedVirSprites - 1,y
                cmp zpVirSpritePosY,x
                bcs Sorted

                sty zpSrcIndex
    FindDst:    dey
                beq MoveBlock
                ldx zpSortedVirSprites - 1,y
                cmp zpVirSpritePosY,x
                bcc FindDst

    MoveBlock:  sty DstIndex

                ldx zpSrcIndex
                lda zpSortedVirSprites,x

    Move:       ldy zpSortedVirSprites - 1,x
                sty zpSortedVirSprites,x
                dex
                cpx DstIndex:#0
                bne Move

                sta zpSortedVirSprites,x
                ldy zpSrcIndex

    Sorted:     iny
                cpy #kMaxVirSprites
                bne Next
                rts
}

//

AllocHardwareSpritesSingleLayer:
{
                ldx NumVirSprites
    Next:       txa
                and #7
                sta zpHardwareSprites - 1,x
                dex
                bne Next
                rts
}

//

AllocHardwareSpritesLayer01:
{
                lda #7
                sta Layer1SpriteIndex
                sec
                sbc NumVirSpritesPerLayer + 1 // Todo: Use max # overlapping layer 1 sprites instead.
                sta MaxLayer0
                sta MinLayer1
                sta Layer0SpriteIndex

                ldx NumVirSprites
    Next:       ldy zpSortedVirSprites - 1,x
                lda VirSpriteColorLayers,y
                bpl Layer1

    Layer0:     ldy Layer0SpriteIndex:#0
                sty zpHardwareSprites - 1,x
                dey
                bpl NoWrap0
                ldy MaxLayer0:#0
    NoWrap0:    sty Layer0SpriteIndex
    Skip0:      dex
                bne Next
                rts

    Layer1:     ldy Layer1SpriteIndex:#0
                sty zpHardwareSprites - 1,x
                dey
                cpy MinLayer1:#0
                bne NoWrap1
                ldy #7
    NoWrap1:    sty Layer1SpriteIndex
                dex
                bne Next
                rts
}

//

AllocHardwareSpritesLayer12:
{
                ldy NumVirSpritesPerLayer + 1
                dey
                sty Layer1SpriteIndex
                sty MaxLayer1 // Todo: Use max # overlapping layer 1 sprites instead.
                sty MinLayer2
                ldy #7
                sty Layer2SpriteIndex

                ldx NumVirSprites
    Next:       ldy zpSortedVirSprites - 1,x
                lda VirSpriteColorLayers,y
                asl
                bmi Layer1

    Layer2:     ldy Layer2SpriteIndex:#0
                sty zpHardwareSprites - 1,x
                dey
                cpy MinLayer2:#0
                bne NoWrap2
                ldy #7
    NoWrap2:    sty Layer2SpriteIndex
                dex
                bne Next
                rts

    Layer1:     ldy Layer1SpriteIndex:#0
                sty zpHardwareSprites - 1,x
                dey
                bpl NoWrap1
                ldy MaxLayer1:#0
    NoWrap1:    sty Layer1SpriteIndex
                dex
                bne Next
                rts
}

//

AllocHardwareSprites:
{
                lda #$ff
    .for (var  i = 0; i < 8; i++)
    {
                sta zpHardwareSpritesStartY + i
    }

                ldy NumVirSprites
                dey
      
    Next:       ldx zpSortedVirSprites,y
                lda VirSpriteColorLayers,x
                bmi Layer0 // %10
                asl
                bmi Layer1 // %01

    Layer2:     lda zpVirSpritePosY,x
                cmp zpHardwareSpritesStartY + 7
                bcc Alloc7
                cmp zpHardwareSpritesStartY + 6
                bcc Alloc6
                cmp zpHardwareSpritesStartY + 5
                bcc Alloc5
                cmp zpHardwareSpritesStartY + 4
                bcc Alloc4
                cmp zpHardwareSpritesStartY + 3
                bcc Alloc3
                cmp zpHardwareSpritesStartY + 2
                bcc Alloc2
                cmp zpHardwareSpritesStartY + 1
                bcc Alloc1
                clc
                bcc Alloc0 // bra

   //

    Alloc7:     ldx #7
                bne Update  // bra
      
    Alloc1:     ldx #1
                bne Update // bra
      
    Alloc2:     ldx #2
                bne Update // bra
      
    Alloc3:     ldx #3
                bne Update // bra
      
    Alloc4:     ldx #4
                bne Update // bra
      
    Alloc5:     ldx #5
                bne Update // bra
      
    Alloc6:     ldx #6
                bne Update // bra

    Alloc0:     ldx #0

    Update:     sbc #kYSpacing - 1
                sta zpHardwareSpritesStartY,x
    Set:        stx zpHardwareSprites,y
                dey
                bpl Next
                rts

   //

    Layer0:     lda zpVirSpritePosY,x
                cmp zpHardwareSpritesStartY + 0
                bcc Alloc0
                cmp zpHardwareSpritesStartY + 1
                bcc Alloc1
                cmp zpHardwareSpritesStartY + 2
                bcc Alloc2
                cmp zpHardwareSpritesStartY + 3
                bcc Alloc3
                cmp zpHardwareSpritesStartY + 4
                bcc Alloc4
                cmp zpHardwareSpritesStartY + 5
                bcc Alloc5
                cmp zpHardwareSpritesStartY + 6
                bcc Alloc6
                clc
                bcc Alloc7 // bra

    Layer1:     lda zpVirSpritePosY,x
                cmp zpHardwareSpritesStartY + 4
                bcc Alloc4
                cmp zpHardwareSpritesStartY + 3
                bcc Alloc3
                cmp zpHardwareSpritesStartY + 5
                bcc Alloc5
                cmp zpHardwareSpritesStartY + 2
                bcc Alloc2
                cmp zpHardwareSpritesStartY + 6
                bcc Alloc6
                cmp zpHardwareSpritesStartY + 1
                bcc Alloc1
                cmp zpHardwareSpritesStartY + 7
                bcc Alloc7
                clc
                bcc Alloc0 // bra
}

//

.segment Code "Multiplexer const data"
   
ClearBit:
.label SetBit = *+1
.byte 255-1, 1, 255-2, 2, 255-4, 4, 255-8, 8
.byte 255-16, 16, 255-32, 32, 255-64, 64, 255-128, 128

//

.segment BSS2 "Multiplexer data"

VirSpritePosXLo:
.fill kMaxVirSprites, 0

VirSpritePosXHi:
.fill kMaxVirSprites, 0

VirSpritePointers:
.fill kMaxVirSprites, 0

// Color + layer (in bits 6-7).
VirSpriteColorLayers:
.fill kMaxVirSprites, 0

NumVirSprites:
.byte 0

NumVirSpritesPerLayer:
.byte 0, 0, 0
