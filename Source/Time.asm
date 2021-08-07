/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Time

//

.macro @TimeUpdate()
{
                inc Time.FrameCountLo
                bne Done
                inc Time.FrameCountHi
    Done:
}

//

.segment BSS2 "Time data"

FrameCountLo:
.byte 0
FrameCountHi:
.byte 0
