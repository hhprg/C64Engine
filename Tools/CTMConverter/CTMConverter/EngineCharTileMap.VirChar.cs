/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

using System.IO;

namespace CTM
{
   partial class EngineCharTileMap
   {
      class VirChar
      {
         public int CharIndex;
         public bool FlipX;
         public bool FlipY;
         public int Color;
         public bool IsSymmetricX;
         public bool IsSymmetricY;
         public bool IsSymmetricXHires;

         public VirChar(int charIndex, int color, bool flipX, bool flipY, bool isSymmetricX, bool isSymmetricY, bool isSymmetricXHires)
         {
            CharIndex = charIndex;
            FlipX = flipX;
            FlipY = flipY;
            Color = color;
            IsSymmetricX = isSymmetricX;
            IsSymmetricY = isSymmetricY;
            IsSymmetricXHires = isSymmetricXHires;
         }

         public VirChar(VirChar other)
         {
            CharIndex = other.CharIndex;
            FlipX = other.FlipX;
            FlipY = other.FlipY;
            Color = other.Color;
            IsSymmetricX = other.IsSymmetricX;
            IsSymmetricY = other.IsSymmetricY;
            IsSymmetricXHires = other.IsSymmetricXHires;
         }

         public bool IsHires()
         {
            return IsHiresColor(Color);
         }

         public bool IsEqual(VirChar other)
         {
            bool isEqual = false;

            if (CharIndex == other.CharIndex)
            {
               if (Color == other.Color)
               {
                  if ((FlipX == other.FlipX) || 
                      (!IsHires() && IsSymmetricX) ||
                      (IsHires() && IsSymmetricXHires))
                  {
                     isEqual = (FlipY == other.FlipY) || IsSymmetricY;
                  }
               }
            }

            return isEqual;
         }

         public int GetCharBits()
         {
            return GetCharBits(false, false);
         }

         public int GetCharBits(bool flipX, bool flipY)
         {
            int charBits = CharIndex;

            flipX = flipX ? !FlipX : FlipX;
            flipY = flipY ? !FlipY : FlipY;

            if (flipX && 
                !(!IsHires() && Instance.IsSymmetricX(CharIndex)) && 
                !(IsHires() && Instance.IsSymmetricXHires(CharIndex)))
            {
               charBits |= FlipXBit;
            }
            if (flipY && !Instance.IsSymmetricY(CharIndex))
            {
               charBits |= FlipYBit;
            }

            return charBits;
         }

         public int GetCharBitsWithColor()
         {
            return GetCharBits() | (Color << ColorBitsIndex);
         }

         public void Write(StreamWriter streamWriter, int primeIndex, int index)
         {
            string line = WordText;
            int charBits = GetCharBitsWithColor();

            line += "$" + charBits.ToString("x4");
            line += IndexCommentText + primeIndex.ToString("x3") + " ($" + index.ToString("x3") + ")";
            streamWriter.WriteLine(line);
         }
      }
   }
}
