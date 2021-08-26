/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace ColorScroll

//

.segment Zeropage "ColorScroll zeropage data"

zpRow:
.fill 1, 0

zpNewDstLo:   
.fill 1, 0

zpNewDstHi:   
.fill 1, 0

zpSrcLo:
.fill 1, 0

zpSrcHi:
.fill 1, 0

zpColumnIndicesLo:   
.fill 1, 0

zpColumnIndicesHi:   
.fill 1, 0

//

.segment Code "ColorScroll code"         

.enum {kShiftLeft=0, kShiftRight=1, kUndoShiftLeft=2}

.const kMaxColorShifts = CharTileMap.kMaxColorShifts // <= 256

// How many screen rows to move colors for at once (i.e. one loop), 6 * 40 <= 256.
.const kNumBlockRows = 6

// Number of blocks needed to move colors for all screen rows.
.const kNumBlocks = ceil(kNumScreenScrollRows / kNumBlockRows)

.const kShiftLeftSrcColMem = kColorMem + kScrollOffset + 1
.const kShiftLeftDstColMem = kColorMem + kScrollOffset + 0
.const kShiftLeftNewColMem = kColorMem + kScrollOffset + kNumVisibleColumns - 1

.const kShiftRightSrcColMem = kColorMem + kScrollOffset + 0
.const kShiftRightDstColMem = kColorMem + kScrollOffset + 1
.const kShiftRightNewColMem = kColorMem + kScrollOffset + 0

.const kUndoShiftLeftSrcColMem = kColorMem + kScrollOffset - 1
.const kUndoShiftLeftDstColMem = kColorMem + kScrollOffset + 0
.const kUndoShiftLeftNewColMem = kColorMem + kScrollOffset + 0

//

Init:
{           
                lda #0
                sta BufferIndex 
                jsr FlipBuffer // Use buffer index 1.

                ldx #0
                ldy #0
    NextRow:    sty Row
   
                // Set color memory address of first (src) column of this screen row.
                lda ColorMemRowAdrLo,y
                sta zpSrcLo
                lda ColorMemRowAdrHi,y
                sta zpSrcHi

                // Find columns where colors change between adjacent columns (going from end of row to start of row). 
                ldy #kNumVisibleColumns - 1
   
    NextColumn: // Dst column index = source column index + 1.
                lda (zpSrcLo),y
                dey
                eor (zpSrcLo),y 
                and #kColorMask
                beq Same

                // Adjacent columns have different colors, store (left) column index in per-row list.
                // Column indices are stored in descending order.
                tya

                // Column indices are double buffered, assumes that BufferIndex is 1 when we get here.
                sta ColumnIndices1,x
                inx
    Same:       tya 
                bne NextColumn               
   
                ldy Row:#0         
                txa

                // Keep index of last list element (+1) for each row.
                sta EndIndexPerRow,y
                iny
                cpy #kNumScreenScrollRows
                bne NextRow

                // Finalize, i.e. combine per-row lists into per-block lists that can execute faster
                // when it's time to shift colors.
                jsr Finalize

                // It's not unsynced since block lists match colors on screen.
                jmp ClearUnsyncedShiftDir
}               

// 

FlipBuffer:
{
                lax BufferIndex
                eor #1
                sta BufferIndex
                tay

                // Store finalized column indices in other (i.e. previous) column indices buffer.
                lda ColumnIndicesLo,x
                sta SyncShiftCommon.PrevColumnIndicesLo
                sta ShiftTileRows.ShiftLeft.FinalizedColumnIndicesLo
                sta ShiftTileRows.ShiftRight.FinalizedColumnIndicesLo
                sta Finalize.FinalizedColumnIndicesLo

                lda ColumnIndicesHi,x
                sta SyncShiftCommon.PrevColumnIndicesHi
                sta ShiftTileRows.ShiftLeft.FinalizedColumnIndicesHi
                sta ShiftTileRows.ShiftRight.FinalizedColumnIndicesHi
                sta Finalize.FinalizedColumnIndicesHi

                // Current column indices will be stored here.
                lda ColumnIndicesLo,y               
                sta zpColumnIndicesLo
                lda ColumnIndicesHi,y               
                sta zpColumnIndicesHi
                rts
}

//

ShiftTileRowsNotLeft:   
                ldy #<(ShiftTileRows.ShiftRight.SrcLo - ShiftTileRows.ShiftLeft.SrcLo) 

// Shift color memory one step left or right.
//
// x = offset into ShiftTileRowsParameters.
// y = offset (in code) of src/dst address of colors when shifting.
ShiftTileRows:   
{
                sty ShiftAdrOffset

                // Set branch offset for desired shift.
                lda ShiftTileRowsParameters + 0,x
                sta BranchOffset

                // Set source color mem address.
                lda ShiftTileRowsParameters + 1,x
                sta ShiftLeft.SrcLo,y
                lda ShiftTileRowsParameters + 2,x
                sta ShiftLeft.SrcHi,y

                // Set destination color mem address.
                lda ShiftTileRowsParameters + 3,x
                sta ShiftLeft.DstLo,y
                lda ShiftTileRowsParameters + 4,x
                sta ShiftLeft.DstHi,y

                // Set new column destination color mem address.
                lda ShiftTileRowsParameters + 5,x
                sta zpNewDstLo
                lda ShiftTileRowsParameters + 6,x
                sta zpNewDstHi

                // Set new column source address.
                lda ShiftTileRowsParameters + 7,x
                sta NewSrcLo
                lda ShiftTileRowsParameters + 8,x
                sta NewSrcHi

                // Move colors block by block (a block is a set of screen rows).
                ldy #0 // y = block index.

    NextBlock:  sty BlockIndex
               
                lax IndexRangePerBlock,y               
                cmp IndexRangePerBlock + 1,y

                bne BranchOffset:ShiftLeft // bne (ShiftLeft or UndoShiftLeft or ShiftRight)        
    BranchBase: beq SetNewCol // bra

    ShiftLeft:  
    {         
                    sta StopIndex
                    ldx IndexRangePerBlock + 1,y
            
                    // Column indices are stored in descending order per row in block.
                    // So iterate over indices from end to start to move columns in ascending order per row.
        NextCol:    dex
        .label FinalizedColumnIndicesLo = *+1
        .label FinalizedColumnIndicesHi = *+2
                    ldy kDefaultAdr,x
        .label SrcLo = *+1
        .label SrcHi = *+2
                    lda kDefaultAdr,y
        .label DstLo = *+1
        .label DstHi = *+2
                    sta kDefaultAdr,y
                    cpx StopIndex:#0 // Actually start index in flattened list.
                    bne NextCol
                    beq SetNewCol // bra
    }               
   
    UndoShiftLeft:
    {
                    // Undo shift left, last column.               
                    ldx NumBlockRows,y
        NextRow:    ldy RowOffsetsPlus37,x
                    lda (zpNewDstLo),y
                    iny
                    sta (zpNewDstLo),y
                    dex
                    bpl NextRow

                    ldy BlockIndex
                    ldx IndexRangePerBlock,y               
                  
                    // Fall through to ShiftRight.
    }
   
    ShiftRight:  
    {         
                    lda IndexRangePerBlock + 1,y
                    sta StopIndex
            
                    // Column indices are stored in descending order per row in block.
                    // Iterate over indices from start to end to move columns in descending order per row.
        NextCol: 
        .label FinalizedColumnIndicesLo = *+1
        .label FinalizedColumnIndicesHi = *+2
                    ldy kDefaultAdr,x
        .label SrcLo = *+1
        .label SrcHi = *+2
                    lda kDefaultAdr,y
        .label DstLo = *+1
        .label DstHi = *+2
                    sta kDefaultAdr,y
                    inx
                    cpx StopIndex:#0
                    bne NextCol
            
                    // Fall through to SetNewCol.
    }               
            
    SetNewCol:  // Set new block column.
                ldy BlockIndex
                ldx NumBlockRows,y
    NextRow:    ldy RowOffsets,x
    .label NewSrcLo = *+1
    .label NewSrcHi = *+2
                lda kDefaultAdr,x
                sta (zpNewDstLo),y
                dex
                bpl NextRow
            
                // Block done. Last block?
                ldy BlockIndex:#0
                cpy #kNumBlocks - 1
                bcs Done

                ldx ShiftAdrOffset:#0         

                // Update addresses for next block. 
                lda ShiftLeft.SrcLo,x
                adc #kNumBlockRows * kNumScreenColumns
                sta ShiftLeft.SrcLo,x
                bcc NoSrcHi
                inc ShiftLeft.SrcHi,x
                clc
            
    NoSrcHi:    lda ShiftLeft.DstLo,x
                adc #kNumBlockRows * kNumScreenColumns
                sta ShiftLeft.DstLo,x
                bcc NoDstHi
                inc ShiftLeft.DstHi,x
                clc               
            
    NoDstHi:    // Move on to start row in new column for next block.
                lda NewSrcLo // New column column is 32 byte aligned.             
                adc #kNumBlockRows
                sta NewSrcLo

                lda zpNewDstLo                    
                adc #kNumBlockRows * kNumScreenColumns
                sta zpNewDstLo
                bcc NoNewDstHi
                inc zpNewDstHi
            
    NoNewDstHi: iny
                jmp NextBlock
    Done:       rts
}

//

// Finish shift by moving colors in color memory.
FinishShift:
{
                lda IsShiftLeft
                beq FinishShiftRight
}

//

FinishShiftLeft:
{
                ldx #<(ShiftTileRowsParameters.Left - ShiftTileRowsParameters)
                ldy #0
                jsr ShiftTileRows
                lda #kLeft
                bne SetUnsyncedShiftDir // bra
}        
            
//

FinishShiftRight:
{
                ldx #<(ShiftTileRowsParameters.Right - ShiftTileRowsParameters)
                jsr ShiftTileRowsNotLeft
                lda #kRight
                bne SetUnsyncedShiftDir // bra                 
}        

//

UndoShiftLeft:
{
                ldx #<(ShiftTileRowsParameters.UndoShiftLeft - ShiftTileRowsParameters)
                jsr ShiftTileRowsNotLeft

                // No need to synchronize since we undid a color shift left which means 
                // that column index row lists are synchronized already.
                jmp ClearUnsyncedShiftDir
}        

//  

StartShiftLeft:
{
                lda #1
                bne StartShift // bra
}

//

StartShiftRight:
{
                lda #0
}

//

StartShift:
{
                sta IsShiftLeft
                jsr SyncShift
    Clear:      lda #kNone
            
                // Fall through to set unsynced shift dir.
}      

.label ClearUnsyncedShiftDir = StartShift.Clear

// Unsynced when colors have been shifted but column index lists don't reflect this yet.
SetUnsyncedShiftDir:
{
                sta UnsyncedShiftDir
                rts
}

//

// Synchronize internal column index lists to reflect last shift.
SyncShift:
{
                lda UnsyncedShiftDir
                bne Shift
                rts
    Shift:      jsr FlipBuffer
                lda UnsyncedShiftDir
                bmi SyncShiftRight

                // Fall through to SyncShiftLeft.
}

//

// Update column index lists after columns shifted one step left.
SyncShiftLeft:   
{      
                lda #kNumVisibleColumns - 2
                ldx #BCS_REL
                ldy #$fe // Add #-1
                bne SyncShiftCommon // bra
}   

// Update column index lists after columns shifted one step right.
SyncShiftRight:   
{      
                lda #0
                ldx #BCC_REL
                ldy #1 // Add #1

                // Fall through to SyncShiftCommon.
}   

// Update column indices after columns shifted one step left or right.
SyncShiftCommon:
{
                sta NewColumn
                eor #kNumVisibleColumns - 2 // A is either 0 or kNumVisibleColumns - 2 here.
                sta DiscardColumn
                stx IgnoreLastColumn
                stx IgnoreFirstColumn
                sty ShiftStep

                // Determine if first/last adjacent columns in each row contain same color.
                ldx #kNumScreenScrollRows - 1
    PrevRow:    lda ColorMemRowAdrLo,x
                sta zpSrcLo
                lda ColorMemRowAdrHi,x
                sta zpSrcHi
                ldy NewColumn:#0
                lda (zpSrcLo),y
                iny
                eor (zpSrcLo),y
                and #kColorMask
                pha // Store on stack from bottom to top row.                
                dex
                bpl PrevRow

                ldy #0 // Column indices buffer index.
                sty StartIndex
                inx // Row index, x = 0
                clc
    NextRow:    stx Row

    IgnoreLastColumn:
                bcc SkipLastColumn // bcc = bra, bcs = brn

                // Check if last column should be included for this row.
                pla
                beq SkipLastColumn
                lda #kNumVisibleColumns - 2
                sta (zpColumnIndicesLo),y
                iny
    SkipLastColumn:

                // Empty row in previous buffer?
                lda EndIndexPerRow,x
                cmp StartIndex
                beq RowDone 

                // Add/subtract one to/from column indices in previous buffer and store in current back buffer,
                // since we are shifting columns one step right/left.
                sta EndIndex
                ldx StartIndex:#0

                // Update row lists by reading lists from previous buffer, updating and writing to current buffer (i.e. double buffered).
    Next:       // Read column index from previous buffer, skip if first screen column, otherwise subtract one and add to current buffer.
    .label PrevColumnIndicesLo = *+1         
    .label PrevColumnIndicesHi = *+2         
                lda kDefaultAdr,x
                cmp DiscardColumn:#0 // Parameter
                beq Skip

                // Discard column =  0 --> c = 1
                // Discard column = 38 --> c = 0

                //clc
                adc ShiftStep:#$ff // Parameter
                sta (zpColumnIndicesLo),y
                iny
    Skip:       inx               
                cpx EndIndex:#0
                bne Next
                stx StartIndex
            
    RowDone:    ldx Row:#0
   
                // c = 1 
    IgnoreFirstColumn:
                bcs SkipFirstColumn // bcs = bra, bcc = brn

                // Check if first column should be included for this row.
                pla
                beq SkipFirstColumn
                lda #0
                sta (zpColumnIndicesLo),y
                iny
    SkipFirstColumn:

                // New end index for this screen row.         
                tya         
                sta EndIndexPerRow,x
                inx
                cpx #kNumScreenScrollRows
                bcc NextRow
               
                // Fall through to finalize.

                // Now updated row lists are stored in current buffer, combine into one list per block 
                // and write result to previous buffer. 
}

//

// Finalize = flatten for groups of N rows (blocks), combine per-row lists into per-block lists.
Finalize:
{
                ldx #0
                ldy #0
                sty EndIndex
                sty ColumnOffset

    NextRow:    lda EndIndexPerRow,x
                cmp EndIndex
                beq RowDone // No colors to move for this row.
               
                // Index of the end of this row's list.
                sta EndIndex

    NextClc:    clc
    Next:       lda (zpColumnIndicesLo),y
                adc ColumnOffset:#0
            
                // Flattened index = column index + offset of block row's first column (0, 40, 80 etc.)
                // Add flattened index to block list. 
    .label FinalizedColumnIndicesLo = *+1
    .label FinalizedColumnIndicesHi = *+2
                sta kDefaultAdr,y
                iny
                cpy EndIndex:#0
                bcc Next
                bne NextClc // Needed because end index can be 0 (if moving 256 colors).

                // On to next row in block.
    RowDone:    inx
                cpx #kNumScreenScrollRows
                bcs Done

                lda BlockColumnOffsets,x
                sta ColumnOffset
                bne NextRow
            
    Done:       // Block done, keep end index per block.
                tya
                pha
                bcc NextRow
            
                // Extract block row end indices.
                ldy #kNumBlocks
    End:        pla               
                // Keep track of start and end indices per block (first start index is always 0).         
                sta IndexRangePerBlock,y         
                dey
                bne End
                rts                              
}
  
//

// Copy leftmost color memory column.
CopyLeftColumn:   
{
                ldy #0
                ldx #kNumScreenScrollRows - 1
    NextRow:    lda ColorMemRowAdrLo,x
                sta zpSrcLo
                lda ColorMemRowAdrHi,x
                sta zpSrcHi
                lda (zpSrcLo),y
                sta LeftmostColumn,x                            
                dex
                bpl NextRow
                rts
}

//   

.segment Code "ColorScroll const data"

NumBlockRows:
.for (var i = 0; i < kNumBlocks - 1; i++)
    .byte kNumBlockRows - 1
.byte kNumScreenScrollRows - (kNumBlocks - 1) * kNumBlockRows - 1

BlockColumnOffsets:
RowOffsets:      
.for (var i = 0; i < kNumBlockRows; i++)
    .byte i * kNumScreenColumns 
.for (var i = kNumBlockRows; i < kNumScreenScrollRows; i++)
    .byte mod(i, kNumBlockRows) * kNumScreenColumns
   
RowOffsetsPlus37:      
.for (var i = 0; i < kNumBlockRows; i++)
    .byte i * kNumScreenColumns + 37 
   
ColumnIndicesLo:
.byte <ColumnIndices0, <ColumnIndices1

ColumnIndicesHi:
.byte >ColumnIndices0, >ColumnIndices1

ColorMemRowAdrLo:         
.for (var i = 0; i < kNumScreenScrollRows; i++)
    .byte <(kColorMem + i * kNumScreenColumns + kScrollOffset)

ColorMemRowAdrHi:         
.for (var i = 0; i < kNumScreenScrollRows; i++)
    .byte >(kColorMem + i * kNumScreenColumns + kScrollOffset)

ShiftTileRowsParameters:
{
    Left:
    .byte ShiftTileRows.ShiftLeft - ShiftTileRows.BranchBase
    .byte <kShiftLeftSrcColMem, >kShiftLeftSrcColMem
    .byte <kShiftLeftDstColMem, >kShiftLeftDstColMem
    .byte <kShiftLeftNewColMem, >kShiftLeftNewColMem
    .byte <Scroll.ColumnColors, >Scroll.ColumnColors

    Right:
    .byte ShiftTileRows.ShiftRight - ShiftTileRows.BranchBase
    .byte <kShiftRightSrcColMem, >kShiftRightSrcColMem
    .byte <kShiftRightDstColMem, >kShiftRightDstColMem
    .byte <kShiftRightNewColMem, >kShiftRightNewColMem
    .byte <Scroll.ColumnColors, >Scroll.ColumnColors

    UndoShiftLeft:
    .byte ShiftTileRows.UndoShiftLeft - ShiftTileRows.BranchBase
    .byte <kUndoShiftLeftSrcColMem, >kUndoShiftLeftSrcColMem
    .byte <kUndoShiftLeftDstColMem, >kUndoShiftLeftDstColMem
    .byte <kUndoShiftLeftNewColMem, >kUndoShiftLeftNewColMem
    .byte <LeftmostColumn, >LeftmostColumn
}

//

.segment BSS2 "ColorScroll data"

IsShiftLeft:
.fill 1, 0

// Shift not yet reflected in ColumnIndices data? Clear (None) when ColumnIndices data synchronized with screen colors.
UnsyncedShiftDir:
.fill 1, 0

EndIndexPerRow:
.fill kNumScreenScrollRows, 0

IndexRangePerBlock:
.fill 1 + kNumBlocks, 0

BufferIndex:
.fill 1, 0

// Double buffered column indices.
ColumnIndices0:
.fill kMaxColorShifts, 0
ColumnIndices1:
.fill kMaxColorShifts, 0

.align 32 // Align to avoid LeftmostColumn page crossing.

LeftmostColumn:
.fill kNumScreenScrollRows, 0
