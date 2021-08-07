/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

using System;
using System.Collections.Generic;
using System.IO;
using System.Diagnostics;
using System.Linq;

namespace CTM
{
   partial class EngineCharTileMap
   {
      class Tile
      {
         public VirChar[,] VirChars; // These vir chars are not part of the engine's mVirChars list.
                                     // They are needed here to support trivial flipping of tiles.

         public Tile(int width, int height)
         {
            VirChars = new VirChar[height, width];
         }

         public void Init(List<VirChar> virChars, Int16[] tileData, int startIndex)
         {
            int h = VirChars.GetLength(0);
            int w = VirChars.GetLength(1);
            int index = startIndex;

            for (int i = 0; i < h; ++i)
            {
               for (int j = 0; j < w; ++j)
               {
                  // LRTB
                  int virCharIndex = tileData[index++];

                  // Create a new vir char that is a copy of the one in the input vir char list.
                  VirChars[i, j] = new VirChar(virChars[virCharIndex]);
               }
            }
         }

         public void FlipY()
         {
            int h = VirChars.GetLength(0);
            int w = VirChars.GetLength(1);

            for (int i = 0; i < h / 2; ++i)
            {
               for (int j = 0; j < w; ++j)
               {
                  VirChar tmp = VirChars[i, j];
                  VirChars[i, j] = VirChars[h - i - 1, j];
                  VirChars[h - i - 1, j] = tmp;

                  VirChars[i, j].FlipY = !VirChars[i, j].FlipY;
                  VirChars[h - i - 1, j].FlipY = !VirChars[h - i - 1, j].FlipY;
               }
            }

            if (h % 2 != 0)
            {
               // Flip center row.
               int i = h / 2;

               for (int j = 0; j < w; ++j)
               {
                  VirChars[i, j].FlipY = !VirChars[i, j].FlipY;
               }
            }
         }

         public void FlipX()
         {
            int h = VirChars.GetLength(0);
            int w = VirChars.GetLength(1);

            for (int i = 0; i < h; ++i)
            {
               for (int j = 0; j < w / 2; ++j)
               {
                  VirChar tmp = VirChars[i, j];
                  VirChars[i, j] = VirChars[i, w - j - 1];
                  VirChars[i, w - j - 1] = tmp;

                  VirChars[i, j].FlipX = !VirChars[i, j].FlipX;
                  VirChars[i, w - j - 1].FlipX = !VirChars[i, w - j - 1].FlipX;
               }
            }

            if (w % 2 != 0)
            {
               // Flip center column.
               int j = w / 2;

               for (int i = 0; i < h; ++i)
               {
                  VirChars[i, j].FlipX = !VirChars[i, j].FlipX;
               }
            }
         }

         public bool Equals(Tile other)
         {
            bool isEqual = true;

            int h = VirChars.GetLength(0);
            int w = VirChars.GetLength(1);

            for (int i = 0; isEqual && i < h; ++i)
            {
               for (int j = 0; isEqual && j < w; ++j)
               {
                  isEqual = VirChars[i, j].IsEqual(other.VirChars[i, j]);
               }
            }

            return isEqual;
         }

         public void Write(
            StreamWriter streamWriter, int tileIndex,
            Dictionary<int, int> virCharBitsToVirCharIndex,
            List<int> tileVirChars, List<int> tileVirCharPrimes)
         {
            int h = VirChars.GetLength(0);
            int w = VirChars.GetLength(1);

            int virCharPrimeBase = (tileVirCharPrimes.Min() / VirPrimeBaseMultiplier) * VirPrimeBaseMultiplier;

            // First export all the vir char prime byte offsets relative to the base (TBLR)
            for (int i = 0; i < w; ++i)
            {
               string line = ByteText;
               for (int j = 0; j < h; ++j)
               {
                  int charBits = VirChars[j, i].GetCharBitsWithColor();
                  int virCharIndex = virCharBitsToVirCharIndex[charBits];
                  int virCharPrimeIndex = tileVirCharPrimes[tileVirChars.IndexOf(virCharIndex)];
                  int offset = virCharPrimeIndex - virCharPrimeBase;

                  Debug.Assert(offset < 256, "Vir char prime offset out of range: " + offset);

                  line += "$" + offset.ToString("x2");

                  if (j < w - 1)
                  {
                     line += ", ";
                  }
                  else if (i == 0)
                  {
                     line += IndexCommentText + tileIndex.ToString("x3");
                  }
               }
               streamWriter.WriteLine(line);
            }

            // Finally export the base shifted down.
            streamWriter.WriteLine(ByteText + "$" + (virCharPrimeBase / VirPrimeBaseMultiplier).ToString("x2"));
         }
      }
   }
}
