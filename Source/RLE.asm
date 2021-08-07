/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace RLE

//

.segment Zeropage "RLE zeropage data"

zpDataLo:
.fill 1, 0
zpDataHi:
.fill 1, 0
zpLength:
.fill 1, 0
zpQueryIndexLo:
.fill 1, 0
zpQueryIndexHi:
.fill 1, 0

//

.segment Code "RLE code"
   
.const kMaxStates = 1

// a = RLE data lo-byte
// y = RLE data hi-byte
// x = RLE state index (0-based index)
InitDecompressor:
{
                sta DataBaseLo,x
                tya
                sta DataBaseHi,x
                lda #0
                sta DataOffsetLo,x
                sta DataOffsetHi,x

                jsr DecodeByte

                ldy zpLength
                iny
                tya
                sta NextIndexLo,x
                bne Done               
                inc NextIndexHi,x
    Done:       rts               
            
// Not needed since memory cleared to zero when we get here.
/*               
                lda #0                  
                sta IndexLo,x
                sec
                adc zpLength // Add 1 + length - 1
                sta NextIndexLo,x
                lda #0
                sta IndexHi,x
                adc #0
                sta NextIndexHi,x
                rts
*/               
}

//

// zpQueryIndexLo = query index lo   
// zpQueryIndexHi = query index hi
// x = RLE state index (0-based index)
GetValue:
{
                // Get value at given index (>=0)
    TryPrevElement:    
                lda zpQueryIndexLo         
                cmp IndexLo,x
                lda zpQueryIndexHi
                sbc IndexHi,x
                bcs TryNextElement

                // Move to previous element (2 bytes earlier, assumes that RLE data is 2-byte aligned).
                lda DataOffsetLo,x
                bne NoWrapPrev
                dec DataOffsetHi,x
    
    NoWrapPrev: sbc #1 // c = 0, subtract 2.
                sta DataOffsetLo,x

                jsr DecodeByte

                // Set index range of previous element.
                lda IndexLo,x
                sta NextIndexLo,x
                clc
                sbc zpLength // subtract 1 + length - 1
                sta IndexLo,x
                lda IndexHi,x
                sta NextIndexHi,x
                sbc #0
                sta IndexHi,x
                bpl TryPrevElement // bra

    TryNextElement:
                lda zpQueryIndexLo
                cmp NextIndexLo,x
                lda zpQueryIndexHi
                sbc NextIndexHi,x
                bcc Done

                //bcs *

                // Move to next element.
                lda DataOffsetLo,x
                adc #1 // c = 1, add 2
                sta DataOffsetLo,x
                bne NoWrapNext
                inc DataOffsetHi,x
    NoWrapNext: jsr DecodeByte

                // Set index range of next element.
                lda NextIndexLo,x
                sta IndexLo,x
                sec
                adc zpLength // Add 1 + length - 1
                sta NextIndexLo,x
                lda NextIndexHi,x
                sta IndexHi,x
                adc #0
                sta NextIndexHi,x
                bpl TryNextElement // bra

    Done:       lda Value,x
                rts
}

//
     
DecodeByte:
{
                lda DataOffsetLo,x
                clc
                adc DataBaseLo,x
                sta zpDataLo
                lda DataOffsetHi,x
                adc DataBaseHi,x
                sta zpDataHi
                ldy #0
                lda (zpDataLo),y
                sta zpLength // Actual length - 1
                iny
                lda (zpDataLo),y
                sta Value,x
                rts
}

//

.segment BSS2 "RLE data"

// Base address of RLE data.
DataBaseLo:
.fill kMaxStates, 0
DataBaseHi:
.fill kMaxStates, 0

// Offset of current RLE element in RLE data.
DataOffsetLo:
.fill kMaxStates, 0
DataOffsetHi:
.fill kMaxStates, 0

// Start uncompressed index of current RLE element.
IndexLo:
.fill kMaxStates, 0
IndexHi:
.fill kMaxStates, 0

// Start uncompressed index of next RLE element.
NextIndexLo:
.fill kMaxStates, 0
NextIndexHi:
.fill kMaxStates, 0

// Value of current RLE element.
Value:
.fill kMaxStates, 0   
