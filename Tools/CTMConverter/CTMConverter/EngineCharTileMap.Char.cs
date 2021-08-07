/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

using System;
using System.Collections.Generic;
using System.IO;

namespace CTM
{
   partial class EngineCharTileMap
   {
      // A char contains the actual char data.
      class Char
      {
         public UInt64 Hash;
         public bool IsSymmetricX;
         public bool IsSymmetricY;
         public bool IsSymmetricXHires;
         public byte[] Data = new byte[8];

         public Char()
         {
            for (int i = 0; i < 8; ++i)
            {
               Data[i] = 0;
            }

            Hash = GenerateHash(Data, 0);
         }

         public Char(Char src)
         {
            Init(src.Data, 0);
         }

         public Char(byte[] charData, int startIndex)
         {
            Init(charData, startIndex);
         }

         public bool UsesMulticolorCharColor()
         {
            bool usesCharColor = false;

            for (int i = 0; i < 8 && !usesCharColor; ++i)
            {
               int row = Data[i];
               for (int j = 0; j < 4 && !usesCharColor; ++j)
               {
                  // Bitpair for char color is %11 (page 117 in Programmer's Reference Guide).
                  usesCharColor = (row & 0x03) == 0x03;
                  row = row >> 2;
               }
            }

            return usesCharColor;
         }

         public void GetData(byte[] charData, int startIndex)
         {
            for (int i = 0; i < 8; ++i)
            {
               charData[startIndex + i] = Data[i];
            }
         }

         public void Init(byte[] charData, int startIndex)
         {
            for (int i = 0; i < 8; ++i)
            {
               Data[i] = charData[startIndex + i];
            }

            Hash = GenerateHash(Data, 0);

            // Detect symmetry.
            bool symmetricY = true;
            for (int i = 0; symmetricY && i < 4; ++i)
            {
               if (Data[i] != Data[7 - i])
               {
                  symmetricY = false;
               }
            }
            IsSymmetricY = symmetricY;

            bool symmetricX = true;
            for (int i = 0; symmetricX && i < 8; ++i)
            {
               if (Data[i] != FlipByteMulticolor(Data[i]))
               {
                  symmetricX = false;
               }
            }
            IsSymmetricX = symmetricX;

            bool symmetricXHires = true;
            for (int i = 0; symmetricXHires && i < 8; ++i)
            {
               if (Data[i] != FlipByte(Data[i]))
               {
                  symmetricXHires = false;
               }
            }
            IsSymmetricXHires = symmetricXHires;
         }

         public void FlipX()
         {
            for (int i = 0; i < 8; ++i)
            {
               Data[i] = FlipByteMulticolor(Data[i]);
            }
            Hash = GenerateHash(Data, 0);
         }

         public void FlipXHires()
         {
            for (int i = 0; i < 8; ++i)
            {
               Data[i] = FlipByte(Data[i]);
            }
            Hash = GenerateHash(Data, 0);
         }

         public void FlipY()
         {
            for (int i = 0; i < 4; ++i)
            {
               byte tmp = Data[i];
               Data[i] = Data[7 - i];
               Data[7 - i] = tmp;
            }
            Hash = GenerateHash(Data, 0);
         }

         public void Write(StreamWriter streamWriter, int index)
         {
            string line = ByteText;
            for (int i = 0; i < 7; ++i)
            {
               line += "$" + Data[i].ToString("x2") + ", ";
            }
            line += "$" + Data[7].ToString("x2") + IndexCommentText + index.ToString("x3");
            streamWriter.WriteLine(line);
         }

         public bool Equals(Char other)
         {
            return Hash == other.Hash;
         }

         static byte FlipByte(byte src)
         {
            int res = 0;
            for (int j = 0; j < 8; ++j)
            {
               if ((src & (1 << j)) != 0)
               {
                  res |= 1 << (7 - j);
               }
            }
            return (byte)res;
         }

         static byte FlipByteMulticolor(byte src)
         {
            int res = 0;
            int shift = 6;
            for (int j = 0; j < 4; ++j)
            {
               res |= ((src >> (6 - shift)) & 3) << shift;
               shift -= 2;
            }
            return (byte)res;
         }

         public static UInt64 GenerateHash(byte[] charData, int startIndex)
         {
            return BitConverter.ToUInt64(charData, startIndex);
         }

         //

         public class Comparer : IComparer<int>
         {
            List<Char> mChars;

            public Comparer(List<Char> chars)
            {
               mChars = chars;
            }

            public int Compare(int a, int b)
            {
               int result;
               Char charA = mChars[a];
               Char charB = mChars[b];

               bool sameSymmetricX = charA.IsSymmetricX == charB.IsSymmetricX;
               bool sameSymmetricXHires = charA.IsSymmetricXHires == charB.IsSymmetricXHires;
               bool sameSymmetricY = charA.IsSymmetricY == charB.IsSymmetricY;

               if (sameSymmetricXHires)
               {
                  if (sameSymmetricX)
                  {
                     if (sameSymmetricY)
                     {
                        result = a > b ? 1 : -1;
                     }
                     else
                     {
                        result = charB.IsSymmetricY ? 1 : -1;
                     }
                  }
                  else
                  {
                     if (charA.IsSymmetricXHires)
                     {
                        // Both are symmetric in x (hires), 
                        // place chars that are only symmetric x (hires) 
                        // before chars that are symmetric x (hires and multicolor).
                        result = charA.IsSymmetricX ? 1 : -1;
                     }
                     else
                     {
                        // Neither is symmetric in x (hires).
                        result = charB.IsSymmetricX ? 1 : -1;
                     }
                  }
               }
               else
               {
                  result = charB.IsSymmetricXHires ? 1 : -1;
               }

               return result;
            }
         }
      }
   }
}
