/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

using System;
using System.Linq;
using System.Text;
using System.IO;
using System.Diagnostics;
using System.Collections.Generic;

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

      public enum ScreenMode
      {
         Hires,
         MultiColor,
         ExtendedColor
      };

      public byte[] FileId = new byte[3];
      public byte Version;
      public byte[] Colors = new byte[5];
      public ColorMethod colorMethod;
      public ScreenMode screenMode = ScreenMode.MultiColor;
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
      public byte[] TileTags;
      public string[] TileNames;
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

                  if (Version == 7)
                  {
                     reader.Read(Colors, 0, Colors.Length);
                     colorMethod = (ColorMethod)reader.ReadByte();
                     screenMode = (ScreenMode)reader.ReadByte();

                     if (screenMode != ScreenMode.ExtendedColor)
                     {
                        Flags = reader.ReadByte();

                        bool isTileSystemEnabled = (Flags & 1) != 0;

                        if (isTileSystemEnabled)
                        {
                           // Character data block.
                           ReadBlockMarker(reader);

                           NumChars = reader.ReadInt16();
                           if (NumChars >= 0)
                           {
                              NumChars++;
                           }

                           CharData = new byte[NumChars * 8];
                           reader.Read(CharData, 0, NumChars * 8);

                           // Character attributes block.
                           CharAttributes = new byte[NumChars];
                           ReadBlockMarker(reader);
                           reader.Read(CharAttributes, 0, NumChars);

                           // Tile data block.
                           ReadBlockMarker(reader);
                           NumTiles = reader.ReadInt16();
                           if (NumTiles >= 0)
                           {
                              NumTiles++;
                           }
                           TileWidth = reader.ReadByte();
                           TileHeight = reader.ReadByte();
                           TileData = new Int16[NumTiles * TileWidth * TileHeight];
                           ReadInt16s(ref TileData, reader);

                           // Tile colors block.
                           if (colorMethod == ColorMethod.PerTile)
                           {
                              TileColors = new byte[NumTiles];
                              ReadBlockMarker(reader);
                              reader.Read(TileColors, 0, NumTiles);
                           }

                           // Tile tags block.
                           TileTags = new byte[NumTiles];
                           ReadBlockMarker(reader);
                           reader.Read(TileTags, 0, NumTiles);

                           // Tile names block.
                           ASCIIEncoding ascii = new ASCIIEncoding();
                           byte[] name = new byte[32];
                           TileNames = new string[NumTiles];
                           ReadBlockMarker(reader);
                           for (int i = 0; i < NumTiles; i++)
                           {
                              TileNames[i] = ReadASCIIString(reader, ascii, name);
                           }

                           // Map data block.
                           ReadBlockMarker(reader);
                           MapWidth = reader.ReadInt16();
                           MapHeight = reader.ReadInt16();
                           MapData = new Int16[MapWidth * MapHeight];
                           ReadInt16s(ref MapData, reader);
                        }
                        else
                        {
                           Console.Error.WriteLine("Tile system is not enabled.");
                        }
                     }
                     else
                     {
                        Console.Error.WriteLine("Extended color mode data not supported.");
                     }
                  }
                  else
                  {
                     Console.Error.WriteLine("CharPad file format version " + Version + " is not supported (only version 7 is supported).");
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
               byte blockIndex = 0;
               bool isTileSystemEnabled = (Flags & 1) != 0;

               writer.Write(FileId);
               writer.Write(Version);
               writer.Write(Colors);
               writer.Write((byte)colorMethod);
               writer.Write((byte)screenMode);
               writer.Write(Flags);

               // Character data block.
               WriteBlockMarker(writer, blockIndex++);
               WriteInt16((Int16)(NumChars - 1), writer);
               writer.Write(CharData);

               // Character attributes block.
               WriteBlockMarker(writer, blockIndex++);
               writer.Write(CharAttributes);

               if (isTileSystemEnabled)
               {
                  // Tile data block.
                  WriteBlockMarker(writer, blockIndex++);
                  WriteInt16((Int16)(NumTiles - 1), writer);
                  writer.Write(TileWidth);
                  writer.Write(TileHeight);
                  WriteInt16s(TileData, writer);

                  // Tile colors block.
                  if (colorMethod == ColorMethod.PerTile)
                  {
                     WriteBlockMarker(writer, blockIndex++);
                     writer.Write(TileColors);
                  }

                  // Tile tags block.
                  WriteBlockMarker(writer, blockIndex++);
                  writer.Write(TileTags);

                  // Tile names block.
                  ASCIIEncoding ascii = new ASCIIEncoding();
                  WriteBlockMarker(writer, blockIndex++);
                  foreach (var name in TileNames)
                  {
                     WriteASCIIString(writer, ascii, name);
                  }
               }

               // Map data block.
               WriteBlockMarker(writer, blockIndex++);
               WriteInt16(MapWidth, writer);
               WriteInt16(MapHeight, writer);
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

      static void WriteBlockMarker(BinaryWriter writer, byte blockIndex)
      {
         // Block marker (0xDA, 0xBN).
         writer.Write(0xda);
         writer.Write(0xb0 + blockIndex);
      }

      static void WriteASCIIString(BinaryWriter writer, ASCIIEncoding ascii, string name)
      {
         byte[] nameBytes = ascii.GetBytes(name);

         writer.Write(nameBytes);
         writer.Write((byte)0);
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

      static string ReadASCIIString(BinaryReader reader, ASCIIEncoding ascii, byte[] nameBytes)
      {
         int len = 0;
         byte letter;

         while ((letter = reader.ReadByte()) != 0)
         {
            nameBytes[len] = letter;
            len++;
         }

         return ascii.GetString(nameBytes, 0, len);
      }

      static int ReadBlockMarker(BinaryReader reader)
      {
         // Block marker (0xDA, 0xBN).
         byte da = reader.ReadByte();
         byte bn = reader.ReadByte();

         return bn - 0xb0;
      }
   }
}
