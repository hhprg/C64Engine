# C64Engine
Partially finished C64 game engine.

Install [KickAssembler](http://theweb.dk/KickAssembler/Main.html#frontpage) to build the project.

Install [VICE](https://vice-emu.sourceforge.io/) to run the built project or to run Bin/Engine.prg.

Install [CharPad](https://subchristsoftware.itch.io/charpad-free-edition) to view the background char tile map file in the Assets folder (from the game IO).

Install [SpritePad](https://subchristsoftware.itch.io/spritepad-pro) to view the sprites file in the Assets folder (from the game Armalyte).

Use this command line to build the project in the Source folder:
`java -jar C:\C64\Tools\KickAssembler\kickass.jar Main.asm`

The included CTMConverter tool in the Tools folder can be used to convert a CharPad file to an assembly source file for the engine.   
Usage: `CTMConverter <CharPad project input filename> <Engine output filename>`    
For example: `CTMConverter IO_L2_PerCharColor_HiresTest.ctm GameCharTileMap.asm`


  
