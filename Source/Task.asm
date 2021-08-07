/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Task

//

.segment Code "Task code"

.const kNumPriorities = 3 // 0-2 where 0 is lowest priority.
.const kMaxListLength = 8 // Must be power of 2.

// All tasks must jmp here to return (i.e. finish execution).
.macro @ReturnFromTask()
{
                jmp Update.ReturnFromTask
}

.macro @TaskInput(taskCode)
{
                lda #<(taskCode - 1)
                ldy #>(taskCode - 1)
}

.macro @AddLowPriorityTask(taskCode)
{
                TaskInput(taskCode)
                jsr AddLowPriority
}

.macro @AddMediumPriorityTask(taskCode)
{
                TaskInput(taskCode)
                jsr AddMediumPriority
}

.macro @AddHighPriorityTask(taskCode)
{
                TaskInput(taskCode)
                jsr AddHighPriority
}

//

AddLowPriority:
{
                ldx #0
                beq Add // bra
}               
            
AddMediumPriority:               
{
                ldx #1
                bne Add // bra
}
               
AddHighPriority:
{
                ldx #2
}

// a = task address - 1 lo
// y = task address - 1 hi
// x = task priority (0-2).
//
// Must be called from interrupt handler with i=1!
Add:
{
                pha
                lda ListLengths,x
#if DEBUG
                cmp #kMaxListLength
                bcc NotFull
                DebugHang() // Should never get here, task list full.
    NotFull:
#endif               
                clc               
                adc ListHeads,x
                anc #kMaxListLength - 1
                adc ListOffsets,x
                inc ListLengths,x
                tax
                pla
                sta CodeAdrLo,x
                tya
                sta CodeAdrHi,x
                rts
}

//        

// Must be called from interrupt handler with i=1!
Update:
{
                // Find highest priority non-empty task list that isn't already active.
                ldx #kNumPriorities - 1
    NextList:    
                // Done if another instance of interrupt handler is already
                // processing this list.
                lda IsListActive,x
                bne Exit
                lda ListLengths,x
                bne ProcessList
                dex
                bpl NextList
    Exit:       rts
   
                // Start processing task list.
    ProcessList:inc IsListActive,x
    NextTask:   dec ListLengths,x
                lda ListHeads,x
                anc #kMaxListLength - 1
                adc ListOffsets,x
                tay

                // Move head one step forward.
                inc ListHeads,x
                txa
                pha
                lda CodeAdrHi,y
                pha
                lda CodeAdrLo,y
                pha
                cli // Allow interrupts since task may span several frames.

                // Execute task (jmp).
                rts
            
    ReturnFromTask:
                sei // Disable interrupts in this critical section.
                pla
                tax
            
                // Process next task in list, if any.
                lda ListLengths,x
                bne NextTask

                // Done processing task list.
                dec IsListActive,x

                // Process next lower priority task list.
                dex
                bpl NextList
    Done:       rts
}

//

ListOffsets:
.for (var i = 0; i < kNumPriorities; i++)
{
    .byte i * kMaxListLength          
}

//

.segment BSS2 "TaskManager data"

IsListActive:
.fill kNumPriorities, 0

// Head (where to process next task) of each (circular) task list.
ListHeads: 
.fill kNumPriorities, 0

ListLengths:
.fill kNumPriorities, 0

// Lo-byte of task code addresses.
CodeAdrLo: 
.fill kMaxListLength * kNumPriorities, 0

// Hi-byte of task addresses.
CodeAdrHi:
.fill kMaxListLength * kNumPriorities, 0
