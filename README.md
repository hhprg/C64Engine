# C64Engine
Partially finished C64 (PAL) game engine.   
Load Bin/Engine.prg in [VICE](https://vice-emu.sourceforge.io/) and type 'sys 2112' to run the demo.  
Watch demo on [YouTube](https://youtu.be/2h9QYfHjf18).

### Technical information and limitations
* Full screen bi-directional side scrolling (currently scrolls max 1 pixel per frame).
* Supports 5x5 or 4x4 tilemaps in CharPad format.
* Supports up to 1024 unique characters. Each character can be flipped/mirrored in x and y for a max total of 4096 characters. Max 256 unique characters can be on screen at any given time. The demo has max 249 unique characters on screen.
* Supports up to 1024 unique tiles. Each tile can be flipped/mirrored in x and y for a max total of 4096 tiles.
* Color per character and full screen color scroll. Max 256 character colors on the screen can move/scroll at any given time. The demo scrolls max 136 character colors.
* The actual max number of colored characters may be less than 4096 in practice, for example when using multiple colors for the same character data. This is due to how the engine currently stores tile data to save memory. This limitation can be worked around at the cost of higher memory usage. 
* Sprite multiplexer supports 24 sprites but the number of sprites can be increased (performance permitting).
* Sprites can be in 3 different layers (depths / "z"). The demo uses this in the section where overlapping sprites are moving in opposite directions in a circle.
* Simple sprite vs sprite box collision detection. No sprite vs character collision detection.
* Animations are in world-space, i.e. at fixed positions in the level/world and not in screen space.
* Task system supports 3 task priorities. Tasks execute in priority order and may span multiple frames. Higher priority tasks may interrupt execution of lower priority tasks. Tasks can run whenever the main engine loop and raster interrupts are not executing.


### Build
Use this command line to build the project in the Source folder:
`java -jar C:\C64\Tools\KickAssembler\kickass.jar Main.asm`

The included CTMConverter tool in the Tools folder converts a CharPad project file to an assembly source file for the engine.   
Usage: `CTMConverter <CharPad project input filename> <Engine output filename>`    
For example: `CTMConverter IO_L2_PerCharColor_HiresTest.ctm GameCharTileMap.asm`


### Recommended software
Install [KickAssembler](http://theweb.dk/KickAssembler/Main.html#frontpage) to build the project.   
Install [VICE](https://vice-emu.sourceforge.io/) to run the built project or to run Bin/Engine.prg (sys 2112 to start).   
Install [CharPad](https://subchristsoftware.itch.io/charpad-free-edition) to view the background char tile map file in the Assets folder (from the game IO).   
Install [SpritePad](https://subchristsoftware.itch.io/spritepad-pro) to view the sprites file in the Assets folder (from the game Armalyte).

  
