/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Scroll

//

.segment Zeropage "Scroll zeropage data"

zpDstScreenMemLo:
.fill 1, 0
zpDstScreenMemHi:
.fill 1, 0

//

.segment Code "Scroll code"         

Init:
{
                jsr ClearUnresolvedPositionChange
                
                // Back buffer is already shifted right, no need to shift right away.
                ldx #0
                stx BackbufferIndex
                stx IsShiftRequested
                inx
                stx IsShiftDone
                
                // Fill initial front buffer.
                lda #0
                sta TileMapCharOffset
                ldx #kScrollOffset
    NextColumn: stx ColumnIndex
                
                lda TileMapCharOffset:#0
                ldx #0
                jsr GetResolveColumn
                inc TileMapCharOffset            
                
                ldx ColumnIndex:#0
                jsr SetBackbufferColumn
                ldx ColumnIndex
                jsr SetColorColumn

                ldx ColumnIndex         
                inx      
                cpx #kNumVisibleColumns + kScrollOffset
                bne NextColumn
                
                // Make newly filled buffer the front buffer.
                jsr FlipBackbuffer
                
                // Prepare back buffer = front buffer shifted one column right.
                // This code has to be consistent with a call to StartShiftRight.
                jsr ShiftColumnsRight
                
                // Position is now position of left side of back buffer.
                jsr CharTileMap.DecreasePosition
                
                // Indicate that back buffer's corresponding decreased position hasn't been used.
                dec UnresolvedPositionChange // -1
                
                // Set leftmost back buffer screen column.
                GetConstCharTileOffset(0)
                jsr GetResolveColumn
                ldx #0 + kScrollOffset
                jsr SetBackbufferColumn
                jmp ColorScroll.Init
}

//   

// UnresolvedPositionChange = -1 if back buffer was shifted one column right (i.e. was prepared in
// anticipation of scrolling right). In that case we have to undo its DecreasePosition.
StartShiftLeft:
{
                lda UnresolvedPositionChange
                beq NoIncrease
                jsr CharTileMap.IncreasePosition
                inc UnresolvedPositionChange // 0
    NoIncrease:
                // Keep a copy of leftmost back buffer column which will need to be discarded later.
                lda #0 + kScrollOffset
                jsr GetBackbufferColumn

                // Increase back buffer tile map position.
                jsr CharTileMap.IncreasePosition

                // Indicate that back buffer's corresponding increased position hasn't been used.
                inc UnresolvedPositionChange // 1

                // Get new column from tile map, discard back buffer column that was copied above and
                // finally resolve new column.
                GetConstCharTileOffset(kNumVisibleColumns - 1)
                jsr GetDiscardResolveColumn
                jsr ShiftColumnsLeft
                
                // Set newly resolved column.
                // Last column (39) is never visible when scrolling.
                ldx #kNumVisibleColumns - 1 + kScrollOffset
                jsr SetBackbufferColumn
                
                jsr ColorScroll.StartShiftLeft
                jmp ColorScroll.CopyLeftColumn
}

//

// UnresolvedPositionChange = 1 if back buffer was shifted one column left (i.e. was prepared in
// anticipation of scrolling left). In that case we have to undo its IncreasePosition.
StartShiftRight:
{
                lda UnresolvedPositionChange
                beq NoDecrease
                jsr CharTileMap.DecreasePosition
                dec UnresolvedPositionChange // 0
    NoDecrease:
                // Keep a copy of rightmost back buffer column which will need to be discarded later.
                lda #kNumVisibleColumns - 1 + kScrollOffset
                jsr GetBackbufferColumn

                // Decrease back buffer tile map position.
                jsr CharTileMap.DecreasePosition
                
                // Indicate that back buffer's corresponding decreased position hasn't been used.
                dec UnresolvedPositionChange // -1

                // Get new column from tile map, discard back buffer column that was copied above and
                // finally resolve new column.
                GetConstCharTileOffset(0)
                jsr GetDiscardResolveColumn
                jsr ShiftColumnsRight

                // Set newly resolved column.
                ldx #0 + kScrollOffset
                jsr SetBackbufferColumn

                jmp ColorScroll.StartShiftRight
}

//

// This is case where we scrolled left and then immediately decided to scroll back right.
// Then we can just flip buffers since back buffer already contains front buffer shifted right.
UndoShiftLeft:
{
                AddHighPriorityTask(UndoColorShiftLeftTask)
                
                jsr ClearUnresolvedPositionChange
                jsr FlipBackbuffer
                jmp CharTileMap.DecreasePosition
}

//

UndoColorShiftLeftTask:
{
                // Todo: Macro to end task.
                jsr ColorScroll.UndoShiftLeft
                ReturnFromTask()
}

//

FinishColorShiftTask:
{
                jsr ColorScroll.FinishShift
                ReturnFromTask()
}

//   

FinishShift:
{
                AddHighPriorityTask(FinishColorShiftTask)    
                
                // We're about to use back buffer, i.e. its position change will be used. 
                jsr ClearUnresolvedPositionChange

                // Fall through to FlipBackbuffer
}

//   
     
FlipBackbuffer:        
{
                lda BackbufferIndex
                eor #1
                sta BackbufferIndex
                rts
}

//   

ClearUnresolvedPositionChange:
{
                lda #0
                sta UnresolvedPositionChange
                rts
}

//

GetDiscardResolveColumn:
{
                jsr CharTileMap.GetColumn
                jsr CharTileMap.DiscardColumn
                jmp CharTileMap.ResolveColumn
}

//

GetResolveColumn:
{
                jsr CharTileMap.GetColumn
                jmp CharTileMap.ResolveColumn
}

//

// Get column to discard when screen shifts, row by row from top to bottom.
GetBackbufferColumn:
{
                ldx BackbufferIndex
}

// a = index of column to get.
// x = screen index (0 or 1).
GetBufferColumn:
{
                sta zpDstScreenMemLo
                lda ScreenAdrHi,x
                sta zpDstScreenMemHi
                clc
                ldx #0
                ldy #0
    NextRow:    lda (zpDstScreenMemLo),y
                sta DiscardColumnPhysicalChars,x
                lda zpDstScreenMemLo
                adc #kNumScreenColumns
                sta zpDstScreenMemLo
                bcc NoHi
                inc zpDstScreenMemHi
    NoHi:       inx
                cpx #kNumScreenScrollRows
                bcc NextRow
                rts
}

// Set new column, row by row from top to bottom.
// x = index of column to set (actually offset of first byte in screen column).
SetBackbufferColumn:
{
                ldy BackbufferIndex
                lda ScreenAdrHi,y
                sta zpDstScreenMemHi
                lda #<ColumnPhysicalChars
                ldy #>ColumnPhysicalChars
}               
            
SetBufferColumn:
{
                sta SrcColumnLo
                sty SrcColumnHi

                // zpDstScreenMemHi is set when we get here.
                stx zpDstScreenMemLo
                ldx #0
                ldy #0
                clc
    NextRow: 
    .label SrcColumnLo = *+1
    .label SrcColumnHi = *+2
                lda kDefaultAdr,x
                sta (zpDstScreenMemLo),y
                lda zpDstScreenMemLo
                adc #kNumScreenColumns
                sta zpDstScreenMemLo
                bcc NoHi
                inc zpDstScreenMemHi
    NoHi:       inx
                cpx #kNumScreenScrollRows
                bcc NextRow
                rts               
}

//

// x = index of column to set.
SetColorColumn:
{
                lda #>kColorMem
                sta zpDstScreenMemHi
                lda #<ColumnColors
                ldy #>ColumnColors
                bne SetBufferColumn // bra   
}

//

.const kDataSize = kNumScreenScrollRows * kNumScreenColumns   
.const kNumBlocks = 4
.const kBlockSize = kDataSize / kNumBlocks   

// Shift columns right.
ShiftColumnsRight:
{
                ldx #kBlockSize-1
                ldy #kBlockSize
                lda #DEX
                bne ShiftColumns  // bra
}

// Shift columns left.
ShiftColumnsLeft:
{
                ldx #kBlockSize
                ldy #kBlockSize-1
                lda #DEY
}
     
// Shift screen columns one step to the left or right.
ShiftColumns:
{
                sta Dec0
                sta Dec2
                eor #DEX^DEY // Turn dex into dey and vice versa.
                sta Dec1
                sta Dec3

                lda BackbufferIndex
                beq ToScreen0

                // From screen 0 to screen 1.
    ToScreen1:
    .for (var i = 0; i < kNumBlocks; i++)
    {
                lda Screen0Mem + i * kBlockSize + kScrollOffset,x
                sta Screen1Mem + i * kBlockSize + kScrollOffset,y
    }
    Dec0:       dey
    Dec1:       dex
                bne ToScreen1
                rts

            // From screen 1 to screen 0.
    ToScreen0:
    .for (var i = 0; i < kNumBlocks; i++)
    {
                lda Screen1Mem + i * kBlockSize + kScrollOffset,x
                sta Screen0Mem + i * kBlockSize + kScrollOffset,y
    }
    Dec2:       dey
    Dec3:       dex
                bne ToScreen0
                rts
}   

//

// a = shift direction   
RequestShift:
{
                sta ShiftDirection
#if DEBUG               
                lda IsShiftRequested
                eor #1
                and IsShiftDone
                bne Okay
                DebugHang()
    Okay:               
#endif // DEBUG               
                ldx #0
                stx IsShiftDone
                inx
                stx IsShiftRequested

                TaskInput(ShiftTask)                
                jmp Task.AddMediumPriority
}

//

ShiftTask:
{
                lda #0
                sta IsShiftRequested

                lda ShiftDirection
                bmi Right

    Left:       jsr StartShiftLeft
                jmp Done

    Right:      jsr StartShiftRight

    Done:       lda #1
                sta IsShiftDone
                ReturnFromTask()
}

//   

.segment Code "Scroll const data"

ScreenAdrBits:   
.byte kScreen0AdrBits, kScreen1AdrBits   

ScreenAdrHi:   
.byte >Screen0Mem, >Screen1Mem

//

.segment BSS2 "Scroll data"

// 1 = left, 0 = stopped, -1 = right
ShiftDirection:
.fill 1, 0

// Set to 1 when shift is done.
IsShiftDone:
.fill 1, 0

// Set to 1 to request shift to start.
IsShiftRequested:
.fill 1, 0

// -1 if back buffer is front buffer shifted right and its content has never been "resolved", i.e. used as front buffer.
//  1 if back buffer is front buffer shifted left and its content has never been "resolved", i.e. used as front buffer.
//  0 if back buffer content has been used as front buffer 
// The value {-1,0,1} is the back buffer's char tile map position offset relative to the front buffer's char tile map position.
UnresolvedPositionChange:
.fill 1, 0 

// 0 or 1.   
BackbufferIndex:
.fill 1, 0 

// Vir chars resolved to physical chars by CharTileMap.
ColumnPhysicalChars:
.fill kNumScreenScrollRows, 0

// Old column with physical chars to be discarded.
DiscardColumnPhysicalChars:
.fill kNumScreenScrollRows, 0

.align 32 // Align to avoid ColumnColors page crossing.

// Colors set by CharTileMap.    
ColumnColors:
.fill kNumScreenScrollRows, 0
