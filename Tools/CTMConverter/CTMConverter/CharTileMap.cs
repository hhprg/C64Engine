/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

using System;
using System.Linq;
using System.Text;
using System.IO;
using System.Diagnostics;

namespace CTM
{
   public class CharTileMap
   {
      public const byte kTileSystemEnabledFlag = 1 << 0;
      public const byte kExpandedDataFlag = 1 << 1;
      public const byte kMultiColorModeEnabledFlag = 1 << 2;

      public enum ColorMethod
      {
         Global,
         PerTile,
         PerCharacter
      };

      public byte[] FileId = new byte[3];
      public byte Version;
      public byte[] Colors = new byte[4];
      public byte colorMethod;
      public byte Flags;
      public Int16 NumChars; // Number of characters
      public Int16 NumTiles; // Number of tiles
      public byte TileWidth;
      public byte TileHeight;
      public Int16 MapWidth;
      public Int16 MapHeight;

      public byte[] CharData;
      public byte[] CharAttributes;
      public Int16[] TileData;
      public byte[] TileColors;
      public Int16[] MapData;

      public byte GetCharColor(int charIndex)
      {
         return GetCharColor(CharAttributes[charIndex]);
      }

      public byte GetCharColor(byte attribute)
      {
         return (byte)(attribute & 0x0f);
      }

      public byte GetCharMaterial(int charIndex)
      {
         return GetCharMaterial(CharAttributes[charIndex]);
      }

      public byte GetCharMaterial(byte attribute)
      {
         return (byte)((attribute >> 4) & 0x0f);
      }

      public CharTileMap(string filename)
      {
         try
         {
            using (Stream stream = new FileStream(filename, FileMode.Open, FileAccess.Read, FileShare.Read))
            {
               if (stream != null)
               {
                  BinaryReader reader = new BinaryReader(stream, Encoding.UTF8);

                  reader.Read(FileId, 0, 3);
                  Version = reader.ReadByte();
                  reader.Read(Colors, 0, 4);
                  colorMethod = reader.ReadByte();
                  Flags = reader.ReadByte();

                  bool hasTiles = (Flags & 1) != 0;
                  bool hasExpandedData = (Flags & 2) != 0;

                  Debug.Assert(!hasExpandedData, "Expanded data not supported.");

                  if (!hasExpandedData)
                  {
                     NumChars = reader.ReadInt16();
                     if (NumChars >= 0)
                     {
                        NumChars++;
                     }
                     NumTiles = reader.ReadInt16();
                     if (NumTiles >= 0)
                     {
                        NumTiles++;
                     }
                     TileWidth = reader.ReadByte();
                     TileHeight = reader.ReadByte();
                     MapWidth = reader.ReadInt16();
                     MapHeight = reader.ReadInt16();

                     CharData = new byte[NumChars * 8];
                     reader.Read(CharData, 0, NumChars * 8);
                     CharAttributes = new byte[NumChars];
                     reader.Read(CharAttributes, 0, NumChars);

                     TileData = new Int16[NumTiles * TileWidth * TileHeight];
                     MapData = new Int16[MapWidth * MapHeight];

                     if (hasTiles)
                     {
                        ReadInt16s(ref TileData, reader);

                        if (colorMethod == (byte)ColorMethod.PerTile)
                        {
                           TileColors = new byte[NumTiles];
                           reader.Read(TileColors, 0, NumTiles);
                        }
                     }

                     ReadInt16s(ref MapData, reader);
                  }
                  else
                  {
                     Console.Error.WriteLine("Expanded data not supported.");
                  }
               }
            }
         } 
         catch (Exception e)
         {
            Console.Error.WriteLine("Unable to load CharPad project file: " + filename);
         }
      }

      // Append src2 to src1.
      public CharTileMap(CharTileMap src1, CharTileMap src2)
      {
         FileId = src1.FileId;
         Version = src1.Version;
         Colors = src1.Colors;
         colorMethod = src1.colorMethod;
         Flags = src1.Flags;

         bool hasTiles = (Flags & 1) != 0;

         NumChars = (Int16)(src1.NumChars + src2.NumChars);
         NumTiles = (Int16)(hasTiles ? src1.NumTiles + src2.NumTiles : 1);
         TileWidth = src1.TileWidth;
         TileHeight = src1.TileHeight;
         MapWidth = (Int16)(src1.MapWidth + src2.MapWidth);
         MapHeight = src1.MapHeight;

         CharData = src1.CharData.Concat(src2.CharData).ToArray();
         CharAttributes = src1.CharAttributes.Concat(src2.CharAttributes).ToArray();

         TileColors = hasTiles ? src1.TileColors.Concat(src2.TileColors).ToArray() : src1.TileColors;
         TileData = hasTiles ? src1.TileData.Concat(src2.TileData).ToArray() : src1.TileData;
         for (int i = src1.TileData.Length; i < TileData.Length; ++i)
         {
            TileData[i] += src1.NumChars;
         }

         MapData = new Int16[src1.MapData.Length + src2.MapData.Length];
         for (int i = 0; i < MapHeight; ++i)
         {
            for (int j = 0; j < src1.MapWidth; ++j)
            {
               MapData[i * MapWidth + j] = src1.MapData[i * src1.MapWidth + j];
            }

            int baseOffset = hasTiles ? src1.NumTiles : src1.NumChars;
            for (int j = 0; j < src2.MapWidth; ++j)
            {
               int k = src1.MapWidth + j;
               MapData[i * MapWidth + k] = (Int16)(src2.MapData[i * src2.MapWidth + j] + baseOffset);
            }
         }
      }

      //

      public void Write(string filename)
      {
         using (Stream stream = new FileStream(filename, FileMode.Create, FileAccess.Write, FileShare.None))
         {
            if (stream != null)
            {
               BinaryWriter writer = new BinaryWriter(stream, Encoding.UTF8);

               writer.Write(FileId);
               writer.Write(Version);
               writer.Write(Colors);
               writer.Write(colorMethod);
               writer.Write(Flags);
               WriteInt16((Int16)(NumChars - 1), writer);
               WriteInt16((Int16)(NumTiles - 1), writer);
               writer.Write(TileWidth);
               writer.Write(TileHeight);
               WriteInt16(MapWidth, writer);
               WriteInt16(MapHeight, writer);

               writer.Write(CharData);
               writer.Write(CharAttributes);

               bool hasTiles = (Flags & 1) != 0;
               if (hasTiles)
               {
                  WriteInt16s(TileData, writer);
                  writer.Write(TileColors);
               }
               WriteInt16s(MapData, writer);
            }
         }
      }

      //

      static void WriteInt16(Int16 src, BinaryWriter writer)
      {
         int lo = src & 0xff;
         int hi = src >> 8;

         writer.Write((byte)lo);
         writer.Write((byte)hi);
      }

      static void WriteInt16s(Int16[] src, BinaryWriter writer)
      {
         for (int i = 0; i < src.Length; ++i)
         {
            WriteInt16(src[i], writer);
         }
      }

      static void ReadInt16s(ref Int16[] result, BinaryReader reader)
      {
         int numElements = result.Length;
         int numBytes = numElements * sizeof(Int16);
         byte[] tmp = new byte[numBytes];
         reader.Read(tmp, 0, numBytes);

         for (int i = 0; i < numElements; ++i)
         {
            int byteIndex = i * sizeof(Int16);
            int lo = tmp[byteIndex];
            int hi = tmp[byteIndex + 1];

            result[i] = (Int16)((hi << 8) + lo);
         }
      }
   }
}
