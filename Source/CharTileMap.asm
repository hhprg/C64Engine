/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace CharTileMap

//
// Data formats summary:
//

// M is map height in number of tiles, N is tile size in number of chars.

// VirChar format (2 bytes)
//
// Bits 12-15: Color.
// Bit 11:     Flip/mirror in y.
// Bit 10:     Flip/mirror in x.
// Bits 0-9:   Char index.

// Tile format (N*N + 1 bytes)
//
// N*N VirChar offsets stored column by column (TBLR).
// VirChar base index / 16, added to VirChar offsets to get resulting VirChar index for each tile VirChar.

// VirTile format (2 bytes)
//
// Bits 12-15: Unused (or color if color per tile)
// Bit 11:     Flip/mirror in y.
// Bit 10:     Flip/mirror in x.
// Bits 0-9:   Tile index.

// TileMap format (M + 1 bytes per column)
// 
// M VirTile offsets per column.
// VirTile base index / 16, added to VirTile offsets to get resulting VirTile index for each map VirTile.

//

.segment Zeropage "CharTileMap zeropage data"

zpIndex:
.fill 1, 0
zpPhysicalChar:
.fill 1, 0
zpVirCharLo:
.fill 1, 0
zpVirCharHi:
.fill 1, 0
zpSrcCharDataLo:
.fill 1, 0
zpSrcCharDataHi:
.fill 1, 0
zpDstCharDataLo:
.fill 1, 0
zpDstCharDataHi:
.fill 1, 0
zpBucketIndex:
.fill 1, 0

zpTileCharIndex:
.fill 1, 0

zpTileMapIndexLo:
.fill 1, 0
zpTileMapIndexHi:
.fill 1, 0

zpTileMapDataLo:   
.fill 1, 0
zpTileMapDataHi:   
.fill 1, 0

zpVirCharDataLo:
.fill 1, 0
zpVirCharDataHi:
.fill 1, 0

zpVirTileDataLo:
.fill 1, 0
zpVirTileDataHi:
.fill 1, 0

zpTileDataLo:
.fill 1, 0
zpTileDataHi:
.fill 1, 0

zpTileVirCharBaseHi:
.fill 1, 0

zpTileFlipBits:
.fill 1, 0

zpTileColumnIndex:
.fill 1, 0

zpColumnRowIndex:
.fill 1, 0

zpLoopIndex:
.fill 1, 0

zpTileMapWidthLo:
.fill 1, 0
zpTileMapWidthHi:
.fill 1, 0

//

.segment Code "GameCharTileMap const data"

#import "GameCharTileMap.asm"

//

.segment Code "CharTileMap code"         

.const kNumBuckets = 32 // Must be power of 2.
.const kUnusedPhysicalChars = 256 - kMaxPhysicalChars // First K chars are unused.
.const kFlipXBit = %00000100
.const kFlipYBit = %00001000
.const kFlipXHiresBit = %00010000
.const kFlipXYBits = kFlipXBit | kFlipYBit  
.const kIndexBitsHi = %00000011 // Char/tile index hi-bits.
.const kNumHiresColors = 8
.const @kNumScreenScrollRows = floor(kNumScreenRows / kTileSize) * kTileSize 
.const @kScrollOffset = (kNumScreenRows - kNumScreenScrollRows) * kNumScreenColumns // Offset of first screen row to scroll.

// Use this macro before calling GetColumn.
.macro @GetConstCharTileOffset(offset) // Non-negative offset!
{
    .if (offset > 0)
    {
                ldx #offset / kTileSize
                lda #mod(offset, kTileSize) 
    }
    else
    {
                lda #0
                tax
    }
}

//

.label kBytesPerTileMapColumn = kTileMapHeight + 1

//

Init:
{
                sec
                ldy #<kMaxPhysicalChars
                ldx #$ff // Physical char index (0-based).

                stx FreeListHead // First available physical char.
                stx CachedTileMapIndexLo // Invalidate cached data.
                stx CachedTileMapIndexHi // kUndefined

    Loop:       lda #kUndefined
                sta PhysicalCharToCharBitsLo,x
                sta PhysicalCharToCharBitsHi,x
                lda #0
                sta PhysicalCharFrequencies,x
                txa
                sbc #1
                sta ListNexts,x
                dex
                dey
                bne Loop

                ldy #kNumBuckets
                lda #0
    Empty:      dey
                sta BucketListLengths,y
                sta BucketListHeads,y
                bne Empty

                // Set per-level data.
                ldx.zp LevelData.zpCurrent
                lda LevelData.TileMapDataLo,x
                sta GetVirTileIndices.TileMapDataBaseLo
                lda LevelData.TileMapDataHi,x
                sta GetVirTileIndices.TileMapDataBaseHi
                lda LevelData.StartTileCharIndex,x               
                sta TileCharIndex
                lda LevelData.StartTileMapIndexLo,x
                sta TileMapIndexLo
                lda LevelData.StartTileMapIndexHi,x
                sta TileMapIndexHi
                lda LevelData.TileMapWidthLo,x
                sta zpTileMapWidthLo
                lda LevelData.TileMapWidthHi,x
                sta zpTileMapWidthHi
                lda LevelData.BackgroundColor,x
                sta $d020
                sta $d021
                lda LevelData.MultiColor1,x
                sta $d022
                lda LevelData.MultiColor2,x
                sta $d023
                rts
}

//   

DiscardColumn:
{
                // Decrease frequencies of physical chars in screen column that is 
                // about to be removed. Free any physical chars whose frequency is 0.
                ldy #kNumScreenScrollRows - 1
                lda #0
    Clear:      ldx Scroll.DiscardColumnPhysicalChars,y               
                sta PhysicalCharsInColumn,x         
                dey
                bpl Clear

                ldy #kNumScreenScrollRows - 1
    NextRow:    ldx Scroll.DiscardColumnPhysicalChars,y
                lda PhysicalCharsInColumn,x
                bne RowDone
            
                // Mark as counted.
                inc PhysicalCharsInColumn,x
               
                // Decrease frequency of physical char.
                dec PhysicalCharFrequencies,x
                bne RowDone

                // No more instances of this physical char, free it.
                sty zpIndex
                stx zpPhysicalChar

                // x = physical char to remove.
                // y = bucket index.
                lda PhysicalCharToCharBitsLo,x
                and #kNumBuckets - 1
                tay

                dcp BucketListLengths,y // dec abs,y

                lda BucketListHeads,y
                cmp zpPhysicalChar
                beq RemoveHead

                // Find element in list.
    Find:       // y = element index (physical char)
                tay
                lda ListNexts,y
                cmp zpPhysicalChar
                bne Find

                // Remove element corresponding to physical char to free.
                lda ListNexts,x
                sta ListNexts,y

    Free:       // Add physical char to list of free physical chars.
                lda FreeListHead
                sta ListNexts,x
                stx FreeListHead
                ldy zpIndex

    RowDone:    dey
                bpl NextRow        
                rts

    RemoveHead:
                // x = physical char to remove.
                // y = bucket index.
                lda ListNexts,x
                sta BucketListHeads,y
                bcs Free // bra
}     

// Allocate physical chars as needed and resolve column.
_ResolveColumn:
{
    Found:      // Found physical char matching char bits.
                txa
                ldy zpIndex
                sta Scroll.ColumnPhysicalChars,y

    RowDone:    dey
                bpl NextRow

                // Mark resolved physical chars in column as not counted.
                ldy #kNumScreenScrollRows - 1
                lda #0
    Clear:      ldx Scroll.ColumnPhysicalChars,y               
                sta PhysicalCharsInColumn,x         
                dey
                bpl Clear
               
                // Update physical char column frequencies.
                ldy #kNumScreenScrollRows - 1
    Count:      ldx Scroll.ColumnPhysicalChars,y               
                lda PhysicalCharsInColumn,x         
                bne Counted
            
                // Mark as counted.
                inc PhysicalCharsInColumn,x

                // Increase frequency of physical char.
                inc PhysicalCharFrequencies,x
    Counted:    dey         
                bpl Count
                rts

               //

    Begin:      ldy #kNumScreenScrollRows - 1
    NextRow:    // y = bucket index.
                lda ColumnCharBitsLo,y
                and #kNumBuckets - 1
                tax
                sta zpBucketIndex
                sty zpIndex

                // Allocate physical char if list is empty.
                lda BucketListLengths,x
                beq Allocate

                // Bucket list is not empty, look for char bits.

                // Extract char bits lo- and hi-byte.
                lda ColumnCharBitsLo,y
                sta CharBitsLo
                lda ColumnCharBitsHi,y
                sta CharBitsHi

                ldy BucketListLengths,x
                lda BucketListHeads,x
    Find:       tax
                // x = physical char index.
                lda PhysicalCharToCharBitsLo,x
                cmp CharBitsLo:#0
                bne Next
                lda PhysicalCharToCharBitsHi,x
                cmp CharBitsHi:#0
                beq Found
    Next:       lda ListNexts,x
                dey
                bne Find

                // Allocate when end of list reached.
                ldx zpBucketIndex

    Allocate:   ldy FreeListHead
                lda ListNexts,y
                sta FreeListHead

                // x = bucket index
                // y = allocated physical char index

                // Make current head next of new head element.
                lda BucketListHeads,x
                sta ListNexts,y

                // Element is head of list.
                tya
                sta BucketListHeads,x
                inc BucketListLengths,x

                // Resolved.
                // x = row index.
                ldx zpIndex
                sta Scroll.ColumnPhysicalChars,x

                // Update mapping from physical char to char bits.
                lda ColumnCharBitsHi,x
                sta PhysicalCharToCharBitsHi,y
                and #kIndexBitsHi
                sta zpSrcCharDataHi
                lda ColumnCharBitsLo,x
                sta PhysicalCharToCharBitsLo,y

                // Set char data source address.
                asl
                rol zpSrcCharDataHi
                asl
                rol zpSrcCharDataHi
                asl
                rol zpSrcCharDataHi
                adc #<CharData
                sta zpSrcCharDataLo
                lda zpSrcCharDataHi
                adc #>CharData
                sta zpSrcCharDataHi

                // Set char data destination address.
                sty zpDstCharDataLo
                lda #0
                asl zpDstCharDataLo
                rol
                asl zpDstCharDataLo
                rol
                asl zpDstCharDataLo
                rol
                adc #>CharSetMem
                sta zpDstCharDataHi

                // Copy char data.

                // y = physical char index.
                // Get flip bits (10-11)
                lax PhysicalCharToCharBitsHi,y
                ldy #7
                and #kFlipYBit
                beq NoFlipY

    FlipY:
    {
                    stx Bits
                    lda zpDstCharDataLo
                    sta DstCharDataLo
                    lda zpDstCharDataHi
                    sta DstCharDataHi
                    ldx #0
        LoopSrc:    lda (zpSrcCharDataLo),y
        .label DstCharDataLo = *+1
        .label DstCharDataHi = *+2
                    sta kDefaultAdr,x
                    inx
                    dey
                    bpl LoopSrc
                    lda Bits:#0
                    bpl CheckFlipX // bra
   }

    NoFlipY:
    {
        Loop:       lda (zpSrcCharDataLo),y
                    sta (zpDstCharDataLo),y
                    dey
                    bpl Loop
                    txa
   }  

    CheckFlipX: and #(kFlipXBit | kFlipXHiresBit)
                beq Done
                ldy #7
                cmp #kFlipXBit
                beq FlipX

    FlipXHires:
    {
        Loop:       lax (zpDstCharDataLo),y
                    lda MirrorHires,x
                    sta (zpDstCharDataLo),y
                    dey
                    bpl Loop
                    bmi Done // bra
    }

    FlipX:
    {
        Loop:       lax (zpDstCharDataLo),y
                    lda MirrorMultiColor,x
                    sta (zpDstCharDataLo),y
                    dey
                    bpl Loop
    }
    Done:           ldy zpIndex
                    jmp RowDone
}

.label ResolveColumn = _ResolveColumn.Begin

//

// Set characters and colors in new column.
// a = char offset
// x = tile offset
GetColumn:
{
                clc
                adc TileCharIndex
    Wrap:       cmp #kTileSize
                bcc Done
                inx
                sbc #kTileSize
                bcs Wrap // bra
    Done:       sta zpTileCharIndex

                // Get current tile map offset
                txa
                adc TileMapIndexLo
                sta zpTileMapIndexLo
                lda TileMapIndexHi
                adc #0
                sta zpTileMapIndexHi

                // Wrap map index if necessary.
                jsr WrapMapIndex

                // Most of the following work only needs to be done when entering
                // a new tile, otherwise we can re-use cached data from last time.
                ldx zpTileMapIndexHi
                lda zpTileMapIndexLo
                cmp CachedTileMapIndexLo
                bne Cache
                cpx CachedTileMapIndexHi
                beq Cached
   
    Cache:      sta CachedTileMapIndexLo
                stx CachedTileMapIndexHi

                // Get vir tile indices for this tile map column.
                jsr GetVirTileIndices

                ldx #kTileMapHeight - 1

    NextRow:    // Get vir tile data (tile color, flip bits and tile index).
                jsr GetVirTileData

                // Get tile data (vir chars that make up tile). 
                jsr GetTileData
                dex
                bpl NextRow

    Cached:     // Extract tile column data (vir chars).
                ldx #kTileMapHeight - 1
    ExtractVirChars:     
                txa
                pha
               
                // Get vir chars of tile.
                jsr GetTileColumn
#if COLOR_PER_TILE               
                jsr GetVirTileColorColumn
#endif               
                pla
                tax
                dex
                bpl ExtractVirChars
                rts
}

// zpTileMapIndexLo/Hi contains 16-bit horizontal tile map index
GetVirTileIndices:
{
                // Get current tile map address.

.if ((kTileMapHeight != 5) && (kTileMapHeight != 6))
    .error "Scroll not implemented for tile map with " + kTileMapHeight + " rows."

                lda zpTileMapIndexHi
                sta zpTileMapDataHi
                lda zpTileMapIndexLo
      
.if (kTileMapHeight == 5)
{
                // x6 ((2 + 1) * 2) since each map column is 6 bytes.
                asl
                rol zpTileMapDataHi
                adc zpTileMapIndexLo
                sta zpTileMapDataLo
                lda zpTileMapDataHi
                adc zpTileMapIndexHi
                asl zpTileMapDataLo
                rol
                sta zpTileMapDataHi
}

.if (kTileMapHeight == 6)
{
                // x7 (8 - 1)) since each map column is 7 bytes.
                sta zpTileMapDataLo
                asl
                rol zpTileMapDataHi
                asl
                rol zpTileMapDataHi
                asl
                rol zpTileMapDataHi
                sec               
                sbc zpTileMapDataLo
                sta zpTileMapDataLo
                lda zpTileMapDataHi
                sbc #0
                sta zpTileMapDataHi
                clc
}
                // Add base address.
                lda zpTileMapDataLo
                adc TileMapDataBaseLo:#0
                sta zpTileMapDataLo
                lda zpTileMapDataHi
                adc TileMapDataBaseHi:#0
                sta zpTileMapDataHi

                // Get vir tile (prime) base (offset) (last byte in map column data).
                ldy #kTileMapHeight
                lda #0
                sta VirTileBaseHi
                lda (zpTileMapDataLo),y

                // x16 (corresponds to kVirPrimeBaseMultiplier in exporter).
                asl
                rol VirTileBaseHi
                asl
                rol VirTileBaseHi
                asl
                rol VirTileBaseHi
                asl
                rol VirTileBaseHi
                sta VirTileBaseLo               
                dey               

                // Extract vir tile indices from map rows.
    NextRow:    lda (zpTileMapDataLo),y
                adc VirTileBaseLo:#0
                sta VirTileIndicesLo,y
                lda #0
                adc VirTileBaseHi:#0
                sta VirTileIndicesHi,y
                dey
                bpl NextRow
                rts
}

//

// Todo: Optimize and merge with GetVirTileIndices above and GetTileData below.

// x = tile row index in tile map column.
GetVirTileData:
{
                // Extract vir tile data (indices, color, flip bits)

                // x2 for word offsets.
                lda VirTileIndicesHi,x
                sta zpVirTileDataHi
                lda VirTileIndicesLo,x
                asl               
                rol zpVirTileDataHi

                // Add VirTileData base address to get vir tile data address.
                adc #<VirTileData
                sta zpVirTileDataLo
                lda zpVirTileDataHi
                adc #>VirTileData
                sta zpVirTileDataHi

                // Extract 2 flip bits (bits 10-11) from hi-byte.
                ldy #1
                lda (zpVirTileDataLo),y
                and #kFlipXYBits
                sta TileFlipBits,x
#if COLOR_PER_TILE   
                // Extract 4-bit (bits 12-15) color from hi-byte.
                lda (zpVirTileDataLo),y
                lsr
                lsr
                lsr
                lsr
                sta VirTileColors,x 
#endif               
                // Extract tile index from bits 0-9.

                // Bits 8-9.
                lda (zpVirTileDataLo),y
                and #kIndexBitsHi
                sta TileIndicesHi,x

                // Bits 0-7.
                dey
                lda (zpVirTileDataLo),y
                sta TileIndicesLo,x
                rts
}

//

// x = tile row index in tile map column [0, kNumTileMapRows - 1)
// zpTileCharIndex = char index in tile [0, kTileSize - 1)
GetTileData:
{
                lda TileIndicesHi,x
                sta zpTileDataHi
                lda TileIndicesLo,x

    .if ((kTileSize != 5) && (kTileSize != 4))
        .error "Scroll not implemented for tile size = " + kTileSize + "."

    .if (kTileSize == 5)
    {
                // tile index * 26 ((4 * 3 + 1) * 2) since each tile is 26 (5 * 5 + 1) bytes. 

                // x3
                asl
                rol zpTileDataHi
                adc TileIndicesLo,x
                sta zpTileDataLo
                lda zpTileDataHi
                adc TileIndicesHi,x
                sta zpTileDataHi

                // x12
                asl zpTileDataLo
                rol zpTileDataHi
                asl zpTileDataLo
                rol zpTileDataHi

                // x13
                lda zpTileDataLo
                adc TileIndicesLo,x
                sta zpTileDataLo
                lda zpTileDataHi
                adc TileIndicesHi,x
                sta zpTileDataHi

                // x26
                asl zpTileDataLo
                rol zpTileDataHi
    }

    .if (kTileSize == 4)
    {
                // tile index * 17 (16 + 1) since each tile is 17 (4 * 4 + 1) bytes. 

                // x17
                asl
                rol zpTileDataHi
                asl
                rol zpTileDataHi
                asl
                rol zpTileDataHi
                asl
                rol zpTileDataHi
                adc TileIndicesLo,x
                sta zpTileDataLo
                lda zpTileDataHi
                adc TileIndicesHi,x
                sta zpTileDataHi
    }

                // Add tile data base address to get tile data address.
                lda zpTileDataLo
                adc #<TileData
                sta TileDataLo,x
                sta zpTileDataLo
                lda zpTileDataHi
                adc #>TileData
                sta TileDataHi,x
                sta zpTileDataHi

                // Get vir char (prime) base (offset)(last byte in tile data).
                lda #0
                sta zpTileVirCharBaseHi
                ldy #kTileSize * kTileSize
                lda (zpTileDataLo),y

                // x16 (corresponds to kVirPrimeBaseMultiplier in exporter).
                asl
                rol zpTileVirCharBaseHi
                asl
                rol zpTileVirCharBaseHi
                asl
                rol zpTileVirCharBaseHi
                asl
                rol zpTileVirCharBaseHi
                sta TileVirCharBaseLo,x
                lda zpTileVirCharBaseHi
                sta TileVirCharBaseHi,x
                rts
}

//   

// x = tile row index in tile map column [0, kNumTileMapRows - 1)
// zpTileCharIndex = char index in tile [0, kTileSize - 1)
GetTileColumn:
{
                // Add tile char offset taking flip x bit into account.
                lda TileFlipBits,x
                sta zpTileFlipBits
                and #kFlipXBit
                bne FlipX

                lda zpTileCharIndex
                bpl AddTileCharIndex // bra

    FlipX:      lda #kTileSize - 1
                sec
                sbc zpTileCharIndex

    AddTileCharIndex:
                sta zpTileColumnIndex

    .if ((kTileSize != 5) && (kTileSize != 4))
        .error "Scroll not implemented for tile size = " + kTileSize + "."

    .if (kTileSize == 5)
    {      
                asl // x5 since 5 bytes per tile column.
                asl
                adc zpTileColumnIndex
    }

    .if (kTileSize == 4)
    {      
                asl // x4 since 4 bytes per tile column.
                asl
    }
                adc TileDataLo,x
                sta zpTileDataLo
                lda TileDataHi,x
                adc #0
                sta zpTileDataHi

                // Set vir char base (offset).
                lda TileVirCharBaseLo,x
                sta VirCharBaseLo
                lda TileVirCharBaseHi,x
                sta VirCharBaseHi

                // Get index of last column row for this tile.
                lda TileEndRow,x
                sta zpColumnRowIndex
                tax

                // Tile data stored as TBLR.
                // Extract vir char offset for each tile row and
                // add base to get resulting vir char index.
                ldy #kTileSize - 1
    NextRow:    lda (zpTileDataLo),y
                adc VirCharBaseLo:#0
                sta ColumnVirCharsLo,x
                lda #0
                adc VirCharBaseHi:#0
                sta ColumnVirCharsHi,x
                dex               
                dey
                bpl NextRow

                // Get char bits and color from vir char data.
                ldx zpColumnRowIndex               
                ldy #kTileSize
                sty zpLoopIndex
    NextVirChar:               
                // x2 since each vir char data is 2 bytes.
                lda ColumnVirCharsLo,x
                asl
                rol ColumnVirCharsHi,x
                adc #<VirCharData               
                sta zpVirCharDataLo
                lda ColumnVirCharsHi,x
                adc #>VirCharData               
                sta zpVirCharDataHi

                // Extract char bits and color from vir char data.
                ldy #0
                lda (zpVirCharDataLo),y
                sta ColumnCharBitsLo,x
                iny
                lda (zpVirCharDataLo),y
                lsr   // Extract color.               
                lsr
                lsr
                lsr
                sta Scroll.ColumnColors,x
                lda (zpVirCharDataLo),y
                and #(kIndexBitsHi | kFlipXYBits) // Mask out color.
                sta ColumnCharBitsHi,x
                dex               
                dec zpLoopIndex                                 
                bne NextVirChar

                // Toggle char flip x bit if tile flip x bit set.
                lda zpTileFlipBits
                and #kFlipXBit
                beq NoFlipX

                // Toggle flip x bits in all tile rows.
                ldy #kTileSize
                ldx zpColumnRowIndex
   
    ToggleFlipX:lda ColumnCharBitsHi,x
                eor #kFlipXBit
                sta ColumnCharBitsHi,x
                dex
                dey
                bne ToggleFlipX
   
    NoFlipX:    // Set flip x hires instead of flip x if needed.       
                ldy #kTileSize
                ldx zpColumnRowIndex               
   
    NextColChar:lda Scroll.ColumnColors,x      
                cmp #kNumHiresColors // c = 1 if multicolor
                bcs NoHires
                lda ColumnCharBitsHi,x
                and #kFlipXBit
                beq NoHires                
                lda ColumnCharBitsHi,x // Hires char, clear flip x and set flip x hires.
                eor #kFlipXBit | kFlipXHiresBit
                sta ColumnCharBitsHi,x
    NoHires:    dex
                dey
                bne NextColChar

                // Set char flip y bit if tile flip y bit set.
                lda zpTileFlipBits
                and #kFlipYBit
                beq NoFlipY

                // Toggle flip y bits in all tile rows and start reversing tile rows (incl. colors).
                ldy #kTileSize
                ldx zpColumnRowIndex
   
    ToggleFlipY:lda ColumnCharBitsHi,x
                eor #kFlipYBit
                pha
                lda ColumnCharBitsLo,x
                pha
                lda Scroll.ColumnColors,x
                pha
                dex
                dey
                bne ToggleFlipY

                // Store tile rows in reverse order.
                ldy #kTileSize
                ldx zpColumnRowIndex
    SetRow:     pla
                sta Scroll.ColumnColors,x
                pla
                sta ColumnCharBitsLo,x
                pla
                sta ColumnCharBitsHi,x
                dex
                dey
                bne SetRow 
            
    NoFlipY:    // Clear flip bits for all symmetric vir chars.

                // Check symmetry x based on char index.               
                lda #kTileSize
                sta zpLoopIndex
                ldx zpColumnRowIndex
    CheckSymmetryX:
                // Only chars 0-255 are allowed to be symmetric in x or y.
                lda ColumnCharBitsHi,x
                and #kIndexBitsHi
                bne NoSymmetry

                lda ColumnCharBitsLo,x
                cmp #kCharSymmetryEnd
                bcs NoSymmetry

                ldy Scroll.ColumnColors,x
                cpy #kNumHiresColors // Colors 0-7 are hi-res.
                bcc Hires               

                cmp #kCharSymmetryXEnd
                bcs NoSymmetryX
                cmp #kCharSymmetryXStart
                bcc NoSymmetryX
                bcs SymmetryX // bra

    Hires:      cmp #kCharSymmetryXHiresEnd
                bcs NoSymmetryX
                //cmp #CharSymmetryXHiresStart // Always 0
                //bcc NoSymmetryX
            
    SymmetryX:  // Clear flip x bit.
                lda ColumnCharBitsHi,x
                and #~(kFlipXBit | kFlipXHiresBit)
                sta ColumnCharBitsHi,x
                lda ColumnCharBitsLo,x
            
    NoSymmetryX:// Check symmetry y based on symmetry table.
                and #7               
                tay
                lda Bits,y
                pha

                // char index / 8.
                lda ColumnCharBitsLo,x
                lsr
                lsr
                lsr
                tay

                pla
                and CharDataSymmetricY,y
                beq NoSymmetry

                // Clear flip y bit.
                lda ColumnCharBitsHi,x
                and #~kFlipYBit
                sta ColumnCharBitsHi,x
   
    NoSymmetry: dex
                dec zpLoopIndex
                bne CheckSymmetryX
                rts
}   

//

#if COLOR_PER_TILE   
GetVirTileColorColumn:
{
                ldx #0
                ldy #0
                clc
    NextTile:   tya
                adc #kTileSize
                sta EndRow
                lda VirTileColors,x               
    Set:        sta Scroll.ColumnColors,y
                iny     
                cpy EndRow:#kTileSize
                bcc Set
                inx
                cpx #kNumTileMapRows
                bcc NextTile
                rts
}
#endif

//

// Returns carry set if it wrapped, carry clear otherwise.
WrapMapIndex:
{
                lda zpTileMapIndexHi
                bpl NoMinWrap

                // Wrap to end of tile map.
                lda zpTileMapIndexLo
                clc
                adc zpTileMapWidthLo
                sta zpTileMapIndexLo
                lda zpTileMapIndexHi
                adc zpTileMapWidthHi
                sta zpTileMapIndexHi
    Done:       rts
            
    NoMinWrap:  cmp zpTileMapWidthHi
                bcc Done
                bne WrapMax
                lda zpTileMapIndexLo
                cmp zpTileMapWidthLo
                bcc Done
    WrapMax:    // Wrap to beginning of tile map.
                lda zpTileMapIndexLo
                sbc zpTileMapWidthLo
                sta zpTileMapIndexLo
                lda zpTileMapIndexHi
                sbc zpTileMapWidthHi
                sta zpTileMapIndexHi
                rts
}

//

IncreasePosition:
{           
                ldy TileCharIndex
                iny
                cpy #kTileSize
                bne UpdatePosition.SetChar
                ldy #0
                inc TileMapIndexLo
                bne UpdatePosition
                inc TileMapIndexHi
}

//

UpdatePosition:
{
                lda TileMapIndexLo
                sta zpTileMapIndexLo
                lda TileMapIndexHi
                sta zpTileMapIndexHi
                jsr WrapMapIndex
                lda zpTileMapIndexLo
                sta TileMapIndexLo
                lda zpTileMapIndexHi
                sta TileMapIndexHi
    SetChar:    sty TileCharIndex
                rts                  
}

//   

DecreasePosition:
{
                // Move to next left char.
                ldy TileCharIndex
                dey
                bpl UpdatePosition.SetChar
                ldy #kTileSize - 1
                lda TileMapIndexLo
                bne NoWrap
                dec TileMapIndexHi
    NoWrap:     dec TileMapIndexLo
                jmp UpdatePosition
}


.segment Code "CharTileMap const data"

// Look-up table for mirroring multi-color bytes.
MirrorMultiColor:
.byte $00,$40,$80,$c0,$10,$50,$90,$d0,$20,$60,$a0,$e0,$30,$70,$b0,$f0
.byte $04,$44,$84,$c4,$14,$54,$94,$d4,$24,$64,$a4,$e4,$34,$74,$b4,$f4
.byte $08,$48,$88,$c8,$18,$58,$98,$d8,$28,$68,$a8,$e8,$38,$78,$b8,$f8
.byte $0c,$4c,$8c,$cc,$1c,$5c,$9c,$dc,$2c,$6c,$ac,$ec,$3c,$7c,$bc,$fc
.byte $01,$41,$81,$c1,$11,$51,$91,$d1,$21,$61,$a1,$e1,$31,$71,$b1,$f1
.byte $05,$45,$85,$c5,$15,$55,$95,$d5,$25,$65,$a5,$e5,$35,$75,$b5,$f5
.byte $09,$49,$89,$c9,$19,$59,$99,$d9,$29,$69,$a9,$e9,$39,$79,$b9,$f9
.byte $0d,$4d,$8d,$cd,$1d,$5d,$9d,$dd,$2d,$6d,$ad,$ed,$3d,$7d,$bd,$fd
.byte $02,$42,$82,$c2,$12,$52,$92,$d2,$22,$62,$a2,$e2,$32,$72,$b2,$f2
.byte $06,$46,$86,$c6,$16,$56,$96,$d6,$26,$66,$a6,$e6,$36,$76,$b6,$f6
.byte $0a,$4a,$8a,$ca,$1a,$5a,$9a,$da,$2a,$6a,$aa,$ea,$3a,$7a,$ba,$fa
.byte $0e,$4e,$8e,$ce,$1e,$5e,$9e,$de,$2e,$6e,$ae,$ee,$3e,$7e,$be,$fe
.byte $03,$43,$83,$c3,$13,$53,$93,$d3,$23,$63,$a3,$e3,$33,$73,$b3,$f3
.byte $07,$47,$87,$c7,$17,$57,$97,$d7,$27,$67,$a7,$e7,$37,$77,$b7,$f7
.byte $0b,$4b,$8b,$cb,$1b,$5b,$9b,$db,$2b,$6b,$ab,$eb,$3b,$7b,$bb,$fb
.byte $0f,$4f,$8f,$cf,$1f,$5f,$9f,$df,$2f,$6f,$af,$ef,$3f,$7f,$bf,$ff

// Look-up table for mirroring hires bytes.
MirrorHires:   
.for (var i = 0; i < 256; i++)
{
    .var dst = 0;
    .for (var j = 0; j < 8; j++)
    {
        .if ((i & (1 << j)) != 0)
            .eval dst = dst | (1 << (7 - j))
    }
    .byte dst
}

// Last row index (in column) of each tile.
TileEndRow:
.for (var i = 0; i < kTileMapHeight; i++)
    .byte i * kTileSize + kTileSize - 1

Bits:
.for (var i = 0; i < 8; i++)
    .byte 1 << i

//

.segment BSS1 "CharTileMap data"

// Boolean table, volatile (re-created every time it's used).         
.label PhysicalCharsInColumn = *-kUnusedPhysicalChars         
.fill kMaxPhysicalChars, 0
      
// Mapping from physical char to corresponding char bits lo-byte.
.label PhysicalCharToCharBitsLo = *-kUnusedPhysicalChars
.fill kMaxPhysicalChars, 0

// Mapping from physical char to corresponding char bits hi-byte.
// Bit 7 = 1 indicates that the physical char is free.
.label PhysicalCharToCharBitsHi = *-kUnusedPhysicalChars
.fill kMaxPhysicalChars, 0

// Number of screen columns each physical char is in.   
.label PhysicalCharFrequencies = *-kUnusedPhysicalChars
.fill kMaxPhysicalChars, 0

// One element per physical char (element index = 0-based physical char index).
.label ListNexts = *-kUnusedPhysicalChars
.fill kMaxPhysicalChars, 0

BucketListHeads:
.fill kNumBuckets, 0

BucketListLengths:
.fill kNumBuckets, 0

// Head of linked list of available physical chars.
FreeListHead:
.byte 0

// Vir chars of the column extracted from the tile map
// (also overlaid resulting char bits).
ColumnVirCharsLo:
ColumnCharBitsLo:
.fill kNumScreenScrollRows, 0
ColumnVirCharsHi:
ColumnCharBitsHi:   
.fill kNumScreenScrollRows, 0

// [0, map width), tile position of left side of screen.
TileMapIndexLo:
.fill 1, 0
TileMapIndexHi:
.fill 1, 0

// [0, kTileSize), tile char index of left side of screen.
TileCharIndex:
.fill 1, 0 

// Data below was cached for this map index.
CachedTileMapIndexLo:
.fill 1, 0
CachedTileMapIndexHi:
.fill 1, 0

VirTileIndicesLo:
.fill kTileMapHeight, 0
VirTileIndicesHi:
.fill kTileMapHeight, 0
#if COLOR_PER_TILE   
VirTileColors:
.fill kTileMapHeight, 0
#endif   
TileIndicesLo:
.fill kTileMapHeight, 0
TileIndicesHi:
.fill kTileMapHeight, 0
TileFlipBits:
.fill kTileMapHeight, 0
 
TileDataLo:
.fill kTileMapHeight, 0
TileDataHi:
.fill kTileMapHeight, 0

TileVirCharBaseLo:
.fill kTileMapHeight, 0
TileVirCharBaseHi:
.fill kTileMapHeight, 0
