/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

namespace CTM
{
   class Program
   {
      static void Main(string[] args)
      {
         if (args.Length > 0)
         {
            CharTileMap charTileMap = new CharTileMap(args[0]);

            if (charTileMap.CharData != null)
            {
               EngineCharTileMap engineCharTileMap = new EngineCharTileMap(charTileMap);

               engineCharTileMap.Process();
               engineCharTileMap.Validate();

               if (args.Length >= 2)
               {
                  engineCharTileMap.Write(args[1]);
               }
            }
         }
         else
         {
            System.Console.Error.WriteLine("Missing CharPad project input file.");
         }
      }
   }
}
