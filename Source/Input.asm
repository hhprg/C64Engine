/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

.filenamespace Input

.macro @InputUpdate()
{
                // Read joystick 2.
                lda $dc00
                eor #%11111111
                tax
                eor Input.JoystickBits
                sta Input.ChangedJoystickBits
                stx Input.JoystickBits
}

.macro @InputGetHeld()
{
                lda Input.JoystickBits
}

.macro @InputGetPressed()
{
                lda Input.JoystickBits
                and Input.ChangedJoystickBits
}

.macro @InputGetReleased()
{
                lda Input.JoystickBits
                eor #$ff
                and Input.ChangedJoystickBits
}

//

.segment BSS2 "Input data"

JoystickBits:
.byte 0

ChangedJoystickBits:
.byte 0
