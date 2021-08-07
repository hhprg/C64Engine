/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

using System.IO;

namespace CTM
{
   partial class EngineCharTileMap
   {
      class VirTile
      {
         public int TileIndex;
         public bool FlipX;
         public bool FlipY;

         public VirTile(int tileIndex, bool flipX, bool flipY)
         {
            TileIndex = tileIndex;
            FlipX = flipX;
            FlipY = flipY;
         }

         public bool Equals(VirTile other)
         {
            return GetBits() == other.GetBits();
         }

         public int GetBits()
         {
            int bits = TileIndex;
            if (FlipX)
            {
               bits |= FlipXBit;
            }
            if (FlipY)
            {
               bits |= FlipYBit;
            }

            return bits;
         }

         public void Write(StreamWriter streamWriter, int index)
         {
            string line = WordText;
            int bits = GetBits();

            line += "$" + bits.ToString("x4");
            line += IndexCommentText + index.ToString("x3");
            streamWriter.WriteLine(line);
         }
      }
   }
}
