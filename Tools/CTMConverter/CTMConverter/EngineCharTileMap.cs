/****************************************************************** 
 * Copyright (C) 2015-2021 Henrik Holmdahl <henrikh.git@gmail.com>
 ******************************************************************/

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;
using System.Diagnostics;

namespace CTM
{
   partial class EngineCharTileMap
   {
      const int ScreenWidth = 40;
      const int MaxNumIndexBits = 10;// Assumes that indices use, at most, lower 10 bits.
      const int FlipXBit = 1 << MaxNumIndexBits;
      const int FlipYBit = 1 << (MaxNumIndexBits + 1);
      const int FlipXHiresBit = 1 << (MaxNumIndexBits + 2);
      const int ColorBitsIndex = MaxNumIndexBits + 2; // Color uses bits 12-15.
      const int MaxNumPhysicalChars = 256;
      const int MaxNumColorShifts = 256;
      const int MaxNumChars = 1 << MaxNumIndexBits;
      const int MaxNumTiles = 1 << MaxNumIndexBits;
      const int VirPrimeBaseMultiplier = 16; // Must be power of 2 for shifting when decoding.
      const int VirPrimeMaxOffset = (255 / VirPrimeBaseMultiplier) * VirPrimeBaseMultiplier;
      const int MaxNumVirChars = VirPrimeBaseMultiplier * 256;
      const int MaxNumVirTiles = VirPrimeBaseMultiplier * 256;

      const string IndentText = "   ";
      const string ByteText = ".byte ";
      const string WordText = ".word ";
      const string ConstText = ".const ";
      const string LabelText = ".label ";
      const string IndexCommentText = " // $";
      const string CharDataLabel = "CharData:";
      const string CharDataIsSymmetricYLabel = "CharDataSymmetricY:";
      const string VirCharDataLabel = "VirCharData:";
      const string TileDataLabel = "TileData:";
      const string VirTileDataLabel = "VirTileData:";
      const string MapDataLabel = "TileMapData:";

      //

      public static EngineCharTileMap Instance = null;

      //

      int _symmetricXStartIndex;       // Index of first Char that is symmetric in x.
      int _symmetricXEndIndex;         // Index of last Char that is symmetric in x.
      int _symmetricXHiresStartIndex;  // Index of first Char that is symmetric in x (hires).
      int _symmetricXHiresEndIndex;    // Index of last Char that is symmetric in x (hires).
      int _symmetricYEndIndex;         // Index of last Char that is symmetric in y.
      int _maxPhysicalChars;           // Max number of physical chars on screen at any point in the tilemap.
      int _maxColorShifts;             // Max number of colors to shift on screen at any point in the tilemap.

      List<Char> _chars = new List<Char>(MaxNumChars);
      List<VirChar> _virChars = new List<VirChar>(MaxNumVirChars);
      List<Tile> _tiles = new List<Tile>(MaxNumTiles);
      List<VirTile> _virTiles = new List<VirTile>(MaxNumVirTiles);
      Dictionary<int, int> _virCharBitsToVirCharIndex = new Dictionary<int, int>(MaxNumVirChars);

      // Each tile has a list of (sorted) unique vir chars.
      List<List<int>> _virCharIndicesPerTile = new List<List<int>>();

      // Resulting list of vir char primes per tile, one-to-one correspondence with _virCharIndicesPerTile.
      List<List<int>> _virCharPrimesPerTile = new List<List<int>>();

      // (many-to-one) mapping from vir char primes to vir chars.
      List<int> _virCharPrimeToVirChar;

      List<List<int>> _virTilesPerMapColumn = new List<List<int>>();
      List<List<int>> _virTilePrimesPerMapColumn = new List<List<int>>();
      List<int> _virTilePrimeToVirTile;

      int[,] _map; // Map containing VirTile indices.

      CharTileMap _charTileMap;

      //

      public EngineCharTileMap(CharTileMap charTileMap)
      {
         _charTileMap = charTileMap;

         Instance = this;
      }

      public void Process()
      {
         InitChars();
         InitTiles();
         InitMap();

         RemoveUnusedAndDuplicates();
         Reorder();

         InitVirCharPrimes();
         InitVirTilePrimes();
      }

      //

      int NumCharColumns()
      {
         return _charTileMap.MapWidth * _charTileMap.TileWidth;
      }

      int NumCharRows()
      {
         return _charTileMap.MapHeight * _charTileMap.TileHeight;
      }

      bool IsSymmetricX(int charIndex)
      {
         return _chars[charIndex].IsSymmetricX;
      }

      bool IsSymmetricXHires(int charIndex)
      {
         return _chars[charIndex].IsSymmetricXHires;
      }

      bool IsSymmetricY(int charIndex)
      {
         return _chars[charIndex].IsSymmetricY;
      }

      //

      void ExtractColumn(int[] columnCharBits, int[] columnColors, int colIndex)
      {
         int numRows = NumCharRows();
         int mapIndexX = colIndex / _charTileMap.TileWidth;

         // Export char bits (char index and flip bits) per column row.
         for (int i = 0; i < numRows; ++i)
         {
            int mapIndexY = i / _charTileMap.TileHeight;
            int virTileIndex = _map[mapIndexY, mapIndexX];

            VirTile virTile = _virTiles[virTileIndex];
            Tile tile = _tiles[virTile.TileIndex];

            int tileColIndex = colIndex % _charTileMap.TileWidth;
            int tileRowIndex = i % _charTileMap.TileHeight;

            if (virTile.FlipX)
            {
               tileColIndex = _charTileMap.TileWidth - 1 - tileColIndex;
            }
            if (virTile.FlipY)
            {
               tileRowIndex = _charTileMap.TileHeight - 1 - tileRowIndex;
            }

            VirChar virChar = tile.VirChars[tileRowIndex, tileColIndex];
            int charBits = virChar.GetCharBits(virTile.FlipX, virTile.FlipY);
            int color = virChar.Color;

            if (virChar.IsHires())
            {
               // Not multicolor, set bit to indicate that it's different from multicolor flipped in x.
               bool flipX = (charBits & FlipXBit) != 0;

               charBits = (charBits & ~FlipXBit) | (flipX ? FlipXHiresBit : 0);
            }

            columnCharBits[i] = charBits;
            columnColors[i] = color;
         }
      }

      //

      public void Validate()
      {
         int numRows = NumCharRows();
         int numColumns = NumCharColumns();
         int[] columnCharBits = new int[numRows];
         int[] columnColors = new int[numRows];
         int[,] mapCharBits = new int[numRows, numColumns];
         int[,] mapColors = new int[numRows, numColumns];

         // Extract char bits (i.e. char index + flip bits) for map.
         for (int i = 0; i < numColumns; ++i)
         {
            ExtractColumn(columnCharBits, columnColors, i);
            for (int j = 0; j < numRows; ++j)
            {
               mapCharBits[j, i] = columnCharBits[j];
               mapColors[j, i] = columnColors[j];
            }
         }

         // Detect maximum number of physical chars on screen at any time
         // (assumes non-wrapping tile map).
         int maxNumActiveChars = 0;
         HashSet<int> activeChars = new HashSet<int>();

         for (int i = 0; i < numColumns - ScreenWidth; ++i)
         {
            activeChars.Clear();
            for (int j = 0; j < ScreenWidth; ++j)
            {
               for (int k = 0; k < numRows; ++k)
               {
                  int charBits = mapCharBits[k, i + j];

                  activeChars.Add(charBits);
               }
            }

            int numActiveChars = activeChars.Count();
            //Debug.Assert(numActiveChars <= MaxNumPhysicalChars, "Too many physical chars: " + numActiveChars + " (map char offset = " + i + ")");
            if (numActiveChars > MaxNumPhysicalChars)
            {
               Console.Error.WriteLine("Too many physical chars on screen (" + numActiveChars + ") at map character position " + i + " (map tile position " + (i / _charTileMap.TileWidth) + ").");
            }
            maxNumActiveChars = numActiveChars > maxNumActiveChars ? numActiveChars : maxNumActiveChars;
         }
         _maxPhysicalChars = maxNumActiveChars;
         Console.WriteLine("Max number of physical chars: " + _maxPhysicalChars);

         // Detect maximum number of color shifts on screen at any point.
         int maxNumColorShifts = 0;

         for (int i = 0; i < numColumns - ScreenWidth; ++i)
         {
            int numColorShifts = 0;

            for (int j = 1; j < ScreenWidth; ++j)
            {
               for (int k = 0; k < numRows; ++k)
               {
                  if (mapColors[k, i + j - 1] != mapColors[k, i + j])
                  {
                     numColorShifts++;
                  }
               }
            }

//            Debug.Assert(numColorShifts <= MaxNumColorShifts, "Too many color shifts: " + numColorShifts + " (map char offset = " + i + ")");
            if (numColorShifts > MaxNumColorShifts)
            {
               Console.Error.WriteLine("Too many color shifts on screen (" + numColorShifts + ") at map character position " + i + " (map tile position " + (i / _charTileMap.TileWidth) + ").");
            }
            maxNumColorShifts = numColorShifts > maxNumColorShifts ? numColorShifts : maxNumColorShifts;
         }
         _maxColorShifts = maxNumColorShifts;
         Console.WriteLine("Max number of color shifts: " + _maxColorShifts);
      }

      //

      public void Write(string filename)
      {
         // Export to text file.
         try
         {
            using (StreamWriter streamWriter = new StreamWriter(filename, false, Encoding.ASCII))
            {
               if (streamWriter != null)
               {
                  // Export data structure containing pointers etc. to the internal data.
                  {
                     string line;

                     line = "//\n// Auto-generated by CTMConverter tool.\n//\n";
                     streamWriter.WriteLine(line);
                     line = "// Max number of color shifts = " + _maxColorShifts;
                     streamWriter.WriteLine(line);
                     line = "// Max number of active physical chars = " + _maxPhysicalChars;
                     streamWriter.WriteLine(line);
                     line = "// Number of chars = " + _chars.Count;
                     streamWriter.WriteLine(line);
                     line = "// Number of vir chars = " + _virChars.Count;
                     streamWriter.WriteLine(line);
                     line = "// Number of vir chars' = " + _virCharPrimeToVirChar.Count;
                     streamWriter.WriteLine(line);
                     line = "// Number of tiles = " + _tiles.Count;
                     streamWriter.WriteLine(line);
                     line = "// Number of vir tiles = " + _virTiles.Count;
                     streamWriter.WriteLine(line);
                     line = "// Number of vir tiles' = " + _virTilePrimeToVirTile.Count;
                     streamWriter.WriteLine(line);
                     line = "// X symmetry (hires) char range = [" + _symmetricXHiresStartIndex + ", " + _symmetricXHiresEndIndex + ")";
                     streamWriter.WriteLine(line);
                     line = "// X symmetry char range = [" + _symmetricXStartIndex + ", " + _symmetricXEndIndex + ")";
                     streamWriter.WriteLine(line);
                     line = "// Y symmetry end char = " + _symmetricYEndIndex;
                     streamWriter.WriteLine(line);

                     streamWriter.WriteLine("\n.filenamespace CharTileMap\n");

                     line = LabelText + "kMaxPhysicalChars = " + _maxPhysicalChars;
                     streamWriter.WriteLine(line);
                     line = LabelText + "kMaxColorShifts = " + _maxColorShifts;
                     streamWriter.WriteLine(line);

                     // Symmetry info.
                     line = LabelText + "kCharSymmetryXHiresStart = $" + _symmetricXHiresStartIndex.ToString("x2");
                     streamWriter.WriteLine(line);
                     line = LabelText + "kCharSymmetryXHiresEnd = $" + _symmetricXHiresEndIndex.ToString("x2");
                     streamWriter.WriteLine(line);
                     line = LabelText + "kCharSymmetryXStart = $" + _symmetricXStartIndex.ToString("x2");
                     streamWriter.WriteLine(line);
                     line = LabelText + "kCharSymmetryXEnd = $" + _symmetricXEndIndex.ToString("x2");
                     streamWriter.WriteLine(line);
                     line = LabelText + "kCharSymmetryYEnd = $" + _symmetricYEndIndex.ToString("x2");
                     streamWriter.WriteLine(line);
                     line = LabelText + "kCharSymmetryEnd = $" + Math.Max(Math.Max(_symmetricXHiresEndIndex, _symmetricXEndIndex), _symmetricYEndIndex).ToString("x2");
                     streamWriter.WriteLine(line);

                     // Tile size.
                     line = LabelText + "kTileSize = " + _charTileMap.TileWidth;
                     streamWriter.WriteLine(line);

                     // Map width and height.
                     line = LabelText + "kTileMapWidth = " + _map.GetLength(1);
                     streamWriter.WriteLine(line);
                     line = LabelText + "kTileMapHeight = " + _map.GetLength(0);
                     streamWriter.WriteLine(line);

                     // Colors.
                     line = LabelText + "kBackgroundColor = " + "$" + _charTileMap.Colors[0].ToString("x2");
                     streamWriter.WriteLine(line);
                     line = LabelText + "kMulticolor1 = " + "$" + _charTileMap.Colors[1].ToString("x2");
                     streamWriter.WriteLine(line);
                     line = LabelText + "kMulticolor2 = " + "$" + _charTileMap.Colors[2].ToString("x2");
                     streamWriter.WriteLine(line);
                  }

                  streamWriter.WriteLine("");
                  streamWriter.WriteLine(".align 8");
                  streamWriter.WriteLine("");

                  // Export char data.
                  streamWriter.WriteLine(CharDataLabel);
                  for (int i = 0; i < _chars.Count; ++i)
                  {
                     _chars[i].Write(streamWriter, i);
                  }
                  streamWriter.WriteLine("");

                  // Export symmetry Y char data.
                  {
                     int numChars = _symmetricYEndIndex;
                     int numBytes = (numChars + 7) / 8;
                     int[] symmetryYBits = new int[numBytes];

                     for (int i = 0; i < numBytes; ++i)
                     {
                        symmetryYBits[i] = 0;
                     }
                     for (int i = 0; i < numChars; ++i)
                     {
                        Char thisChar = _chars[i];
                        int bit = 1 << (i % 8);
                        int index = i / 8;

                        if (thisChar.IsSymmetricY)
                        {
                           symmetryYBits[index] |= bit;
                        }
                     }

                     streamWriter.WriteLine(CharDataIsSymmetricYLabel);
                     for (int i = 0; i < numBytes; ++i)
                     {
                        streamWriter.WriteLine(ByteText + "%" + ToBinary(symmetryYBits[i], 8) + " // $" + (i * 8).ToString("x3") + " - $" + (i * 8 + 7).ToString("x3"));
                     }
                     streamWriter.WriteLine("");
                  }

                  // Export vir char data (actually vir char prime data).
                  streamWriter.WriteLine(VirCharDataLabel);
                  for (int i = 0; i < _virCharPrimeToVirChar.Count; ++i)
                  {
                     int virCharIndex = _virCharPrimeToVirChar[i];
                     _virChars[virCharIndex].Write(streamWriter, i, virCharIndex);
                  }

                  streamWriter.WriteLine("");

                  // Export tile data.
                  {
                     streamWriter.WriteLine(TileDataLabel);
                     for (int i = 0; i < _tiles.Count; ++i)
                     {
                        _tiles[i].Write(streamWriter, i, _virCharBitsToVirCharIndex, _virCharIndicesPerTile[i], _virCharPrimesPerTile[i]);
                     }
                  }

                  streamWriter.WriteLine("");

                  // Export vir tile (prime) data.
                  streamWriter.WriteLine(VirTileDataLabel);
                  for (int i = 0; i < _virTilePrimeToVirTile.Count; ++i)
                  {
                     _virTiles[_virTilePrimeToVirTile[i]].Write(streamWriter, i);
                  }

                  streamWriter.WriteLine("");

                  // Export tile map.
                  {
                     int h = _map.GetLength(0);
                     int w = _map.GetLength(1);

                     streamWriter.WriteLine(MapDataLabel);

                     for (int j = 0; j < w; ++j)
                     {
                        List<int> virTiles = _virTilesPerMapColumn[j];
                        List<int> virTilePrimes = _virTilePrimesPerMapColumn[j];

                        string line = ByteText;
                        int virTilePrimeBase = (virTilePrimes.Min() / VirPrimeBaseMultiplier) * VirPrimeBaseMultiplier;

                        for (int i = 0; i < h; ++i)
                        {
                           int virTileIndex = _map[i, j];
                           int virTilePrimeIndex = virTilePrimes[virTiles.IndexOf(virTileIndex)];

                           line += "$" + ((virTilePrimeIndex - virTilePrimeBase) & 0xff).ToString("x2") + ", ";
                        }
                        line += "$" + (virTilePrimeBase / VirPrimeBaseMultiplier).ToString("x2");
                        line += IndexCommentText + j.ToString("x3");
                        streamWriter.WriteLine(line);
                     }
                  }
               }
            }
         }
         catch (Exception e)
         {
            Console.Error.WriteLine("Unable to write engine output file: " + filename);
         }
      }

      //

      void InitMap()
      {
         int w = _charTileMap.MapWidth;
         int h = _charTileMap.MapHeight;

         _map = new int[h, w];
         for (int i = 0; i < h; ++i)
         {
            // LRTB
            for (int j = 0; j < w; ++j)
            {
               // Extract tile map data into 2D array tile map.
               // Tile map data correspond to vir tile indices.
               int tileMapIndex = i * w + j;
               int virTileIndex = _charTileMap.MapData[tileMapIndex];

               _map[i, j] = virTileIndex;
            }
         }
      }

      //

      void InitTiles()
      {
         int w = _charTileMap.TileWidth;
         int h = _charTileMap.TileHeight;
         Tile tmpTile = new Tile(w, h);

         for (int i = 0; i < _charTileMap.NumTiles; ++i)
         {
            int tileDataIndex = i * w * h;

            // Create a tile (which contains references to vir chars).
            tmpTile.Init(_virChars, _charTileMap.TileData, tileDataIndex);

            // See if it's a duplicate tile or if a flipped version of it already exists.
            bool flipX = false;
            bool flipY = false;
            int tileIndex = GetTileIndex(tmpTile);

            if (tileIndex < 0)
            {
               tmpTile.FlipY();

               flipY = true;
               tileIndex = GetTileIndex(tmpTile);

               if (tileIndex < 0)
               {
                  tmpTile.FlipX();

                  flipX = true;
                  tileIndex = GetTileIndex(tmpTile);

                  if (tileIndex < 0)
                  {
                     tmpTile.FlipY();

                     flipY = false;
                     tileIndex = GetTileIndex(tmpTile);
                  }
               }
            }

            if (tileIndex < 0)
            {
               // No duplicate or flipped version found, add new (unflipped) tile.
               flipX = false;
               flipY = false;
               tileIndex = _tiles.Count;

               Tile newTile = new Tile(w, h);

               newTile.Init(_virChars, _charTileMap.TileData, tileDataIndex);
               _tiles.Add(newTile);
            }

            VirTile virTile = new VirTile(tileIndex, flipX, flipY);
            _virTiles.Add(virTile);
         }
      }

      void InitChars()
      {
         Char tmpChar = new Char();

         for (int i = 0; i < _charTileMap.NumChars; ++i)
         {
            // A char contains the actual char data.
            int charDataIndex = i * 8; // 8 bytes of data per char

            tmpChar.Init(_charTileMap.CharData, charDataIndex);

            int charIndex = GetCharIndex(tmpChar);
            bool flipX = false;
            bool flipY = false;

            // Detect if color is used by any pixels in char, if not use default color.
            // To avoid outputing multiple empty vir chars with different (invisible) colors.
            int color = _charTileMap.GetCharColor(i);

            // Look for a flipped version of the char and use it combined with flip flags as needed.
            if (charIndex < 0)
            {
               tmpChar.FlipY();

               flipY = true;
               charIndex = GetCharIndex(tmpChar);

               if (charIndex < 0)
               {
                  if (IsHiresColor(color))
                  {
                     tmpChar.FlipXHires();
                  }
                  else
                  {
                     tmpChar.FlipX();
                  }

                  flipX = true;
                  charIndex = GetCharIndex(tmpChar);

                  if (charIndex < 0)
                  {
                     tmpChar.FlipY();

                     flipY = false;
                     charIndex = GetCharIndex(tmpChar);
                  }
               }
            }

            if (charIndex < 0)
            {
               // No flipped versions of the char data found, add new char.
               flipX = false;
               flipY = false;
               charIndex = _chars.Count;

               _chars.Add(new Char(_charTileMap.CharData, charDataIndex));
            }

            // One vir char per original (unflipped) char data, in same order.
            // This way tile map char indices reference vir chars.
            Char thisChar = _chars[charIndex];
            VirChar virChar = new VirChar(charIndex, color, flipX, flipY, thisChar.IsSymmetricX, thisChar.IsSymmetricY, thisChar.IsSymmetricXHires);

            _virChars.Add(virChar);
         }
      }

      void UpdateTileMap(int[] oldToNew)
      {
         int h = _map.GetLength(0);
         int w = _map.GetLength(1);

         for (int i = 0; i < h; ++i)
         {
            for (int j = 0; j < w; ++j)
            {
               _map[i, j] = oldToNew[_map[i, j]];
            }
         }
      }

      void RemoveDuplicateVirTiles()
      {
         int numOldVirTiles = _virTiles.Count;
         int[] oldToNew = new int[numOldVirTiles];
         List<VirTile> newVirTiles = new List<VirTile>(numOldVirTiles);

         // Remove duplicate vir tiles.
         for (int i = 0; i < numOldVirTiles; ++i)
         {
            VirTile virTile = _virTiles[i];
            int index = newVirTiles.FindIndex(x => x.Equals(virTile));
            if (index < 0)
            {
               index = newVirTiles.Count;
               newVirTiles.Add(virTile);
            }
            oldToNew[i] = index;
         }
         _virTiles = newVirTiles;

         // Update tile map accordingly.
         UpdateTileMap(oldToNew);
      }

      void RemoveUnusedVirTiles()
      {
         int h = _map.GetLength(0);
         int w = _map.GetLength(1);
         int numOldVirTiles = _virTiles.Count;
         bool[] tilesUsed = new bool[numOldVirTiles];

         // Find all used vir tiles.
         for (int i = 0; i < numOldVirTiles; ++i)
         {
            tilesUsed[i] = false;
         }
         for (int i = 0; i < h; ++i)
         {
            for (int j = 0; j < w; ++j)
            {
               tilesUsed[_map[i, j]] = true;
            }
         }

         // Remove all unused vir tiles.
         int[] oldToNew = new int[numOldVirTiles];
         List<VirTile> newVirTiles = new List<VirTile>(numOldVirTiles);

         for (int i = 0; i < numOldVirTiles; ++i)
         {
            if (tilesUsed[i])
            {
               oldToNew[i] = newVirTiles.Count;
               newVirTiles.Add(_virTiles[i]);
            }
         }
         _virTiles = newVirTiles;

         // Update tile map accordingly.
         UpdateTileMap(oldToNew);
      }

      void RemoveUnusedTiles()
      {
         int numOldTiles = _tiles.Count;
         bool[] tilesUsed = new bool[numOldTiles];

         for (int i = 0; i < numOldTiles; ++i)
         {
            tilesUsed[i] = false;
         }

         for (int i = 0; i < _virTiles.Count; ++i)
         {
            tilesUsed[_virTiles[i].TileIndex] = true;
         }

         int[] oldToNew = new int[numOldTiles];
         List<Tile> newTiles = new List<Tile>(numOldTiles);
         for (int i = 0; i < numOldTiles; ++i)
         {
            if (tilesUsed[i])
            {
               oldToNew[i] = newTiles.Count;
               newTiles.Add(_tiles[i]);
            }
         }
         _tiles = newTiles;

         // Update vir tiles accordingly.
         for (int i = 0; i < _virTiles.Count; ++i)
         {
            _virTiles[i].TileIndex = oldToNew[_virTiles[i].TileIndex];
         }
      }

      void RemoveUnusedChars()
      {
         int numOldChars = _chars.Count;
         bool[] charsUsed = new bool[numOldChars];

         for (int i = 0; i < numOldChars; ++i)
         {
            charsUsed[i] = false;
         }

         // Chars are referenced by vir chars in tiles.
         for (int i = 0; i < _tiles.Count; ++i)
         {
            Tile tile = _tiles[i];

            foreach (VirChar virChar in tile.VirChars)
            {
               charsUsed[virChar.CharIndex] = true;
            }
         }

         int[] oldToNew = new int[numOldChars];
         List<Char> newChars = new List<Char>(numOldChars);
         for (int i = 0; i < numOldChars; ++i)
         {
            if (charsUsed[i])
            {
               oldToNew[i] = newChars.Count;
               newChars.Add(_chars[i]);
            }
         }
         _chars = newChars;

         // Update vir chars (via tiles) accordingly.
         for (int i = 0; i < _tiles.Count; ++i)
         {
            Tile tile = _tiles[i];

            foreach (VirChar virChar in tile.VirChars)
            {
               virChar.CharIndex = oldToNew[virChar.CharIndex];
            }
         }
      }

      void RemoveUnusedAndDuplicates()
      {
         // Must be called after extracting tile map.

         RemoveDuplicateVirTiles();
         RemoveUnusedVirTiles();
         Debug.Assert(_virTiles.Count <= MaxNumVirTiles, "Too many vir tiles: " + _virTiles.Count);

         RemoveUnusedTiles();
         Debug.Assert(_tiles.Count <= MaxNumTiles, "Too many tiles: " + _tiles.Count);

         RemoveUnusedChars();
         Debug.Assert(_chars.Count <= MaxNumChars, "Too many chars: " + _chars.Count);
      }

      //

      // Re-order chars to make it easy to detect chars that are symmetric in x or y at run time.
      void ReorderCharsBySymmetry()
      {
         int numChars = _chars.Count;

         List<int> charOrder = new List<int>(numChars);
         for (int i = 0; i < numChars; ++i)
         {
            // Start with all chars in their original order.
            charOrder.Add(i);
         }

         // Sort so that chars which are symmetric in x come first, followed by chars
         // that are symmetric in y and finally all non-symmetric chars.
         // This lets us detect if a char index references a symmetric in x
         // char by comparing it to a given index range.
         Char.Comparer comparer = new Char.Comparer(_chars);
         charOrder.Sort(comparer);

         // Re-order chars to match sorted order.
         List<Char> newChars = new List<Char>(numChars);
         int[] oldToNew = new int[numChars];
         for (int i = 0; i < numChars; ++i)
         {
            int old = charOrder[i];

            oldToNew[old] = i;
            newChars.Add(_chars[old]);
         }
         _chars = newChars;

         // Update tiles' vir chars' char references accordingly.
         for (int i = 0; i < _tiles.Count; ++i)
         {
            Tile tile = _tiles[i];

            foreach (VirChar virChar in tile.VirChars)
            {
               virChar.CharIndex = oldToNew[virChar.CharIndex];
            }
         }

         // Find range of symmetric x (hires) chars.
         {
            int symmetricXStart = 0;
            int numSymmetricX = 0;
            for (int i = 0; i < numChars; ++i)
            {
               if (_chars[i].IsSymmetricXHires)
               {
                  if (numSymmetricX == 0)
                  {
                     symmetricXStart = i;
                  }
                  ++numSymmetricX;
               }
               else
               {
                  break;
               }
            }
            _symmetricXHiresStartIndex = symmetricXStart;
            _symmetricXHiresEndIndex = symmetricXStart + numSymmetricX;
            Debug.Assert(_symmetricXHiresEndIndex < 256, "Too many symmetric x (hires) chars: " + _symmetricXHiresEndIndex);
         }

         // Find range of symmetric x chars.
         {
            int symmetricXStart = 0;
            int numSymmetricX = 0;
            for (int i = 0; i < numChars; ++i)
            {
               if (_chars[i].IsSymmetricX)
               {
                  if (numSymmetricX == 0)
                  {
                     symmetricXStart = i;
                  }
                  ++numSymmetricX;
               }
               else if (!_chars[i].IsSymmetricXHires)
               {
                  break;
               }
            }
            _symmetricXStartIndex = symmetricXStart;
            _symmetricXEndIndex = symmetricXStart + numSymmetricX;
            Debug.Assert(_symmetricXEndIndex < 256, "Too many symmetric x chars: " + _symmetricXEndIndex);
         }

         // Find range of symmetric y chars.
         _symmetricYEndIndex = 0;
         for (int i = 0; i < numChars; ++i)
         {
            if (_chars[i].IsSymmetricY)
            {
               _symmetricYEndIndex = i + 1;
            }
         }
      }

      void ReorderVirChars()
      {
         // Clear list of original vir chars since tiles reference copies of original vir chars.
         _virChars.Clear();

         // Add vir chars in order of occurance in tiles.
         for (int i = 0; i < _tiles.Count; ++i)
         {
            Tile tile = _tiles[i];

            foreach (VirChar virChar in tile.VirChars)
            {
               int charBits = virChar.GetCharBitsWithColor();

               if (!_virCharBitsToVirCharIndex.ContainsKey(charBits))
               {
                  _virCharBitsToVirCharIndex[charBits] = _virChars.Count;
                  _virChars.Add(virChar);
               }
            }
         }
      }

      void ReorderVirTiles()
      {
         int numVirTiles = _virTiles.Count;
         int[] oldToNew = new int[numVirTiles];
         List<VirTile> newVirTiles = new List<VirTile>(numVirTiles);

         for (int i = 0; i < numVirTiles; ++i)
         {
            oldToNew[i] = -1;
         }

         int h = _map.GetLength(0);
         int w = _map.GetLength(1);

         // Order vir tiles in order of occurance in tile map (TBLR).
         for (int j = 0; j < w; ++j)
         {
            for (int i = 0; i < h; ++i)
            {
               int oldVirTileIndex = _map[i, j];
               if (oldToNew[oldVirTileIndex] < 0)
               {
                  oldToNew[oldVirTileIndex] = newVirTiles.Count;
                  newVirTiles.Add(_virTiles[oldVirTileIndex]);
               }

               _map[i, j] = oldToNew[oldVirTileIndex];
            }
         }

         _virTiles = newVirTiles;
      }

      void Reorder()
      {
         ReorderCharsBySymmetry();
         Debug.Assert(_symmetricYEndIndex < 256, "Too many symmetric y chars: " + _symmetricYEndIndex);

         ReorderVirChars();
         Debug.Assert(_virChars.Count <= MaxNumVirChars, "Too many vir chars: " + _virChars.Count);

         ReorderVirTiles();
      }

      //

      void InitVirCharPrimes()
      {
         // Vir chars are sorted in order of appearance in tiles when we get here.

         // Each vir char has a list of vir char primes (duplicates of vir char at different indices in resulting vir char prime list).
         List<List<int>> virCharPrimesPerVirChar = new List<List<int>>();

         // Start with empty list of vir char prime indices per vir char.
         for (int i = 0; i < _virChars.Count; ++i)
         {
            virCharPrimesPerVirChar.Add(new List<int>());
         }

         // Create sorted list of unique vir char indices per tile.
         for (int i = 0; i < _tiles.Count; ++i)
         {
            Tile tile = _tiles[i];
            List<int> tileVirCharIndices = new List<int>();

            foreach (VirChar virChar in tile.VirChars)
            {
               int charBits = virChar.GetCharBitsWithColor();

               tileVirCharIndices.Add(_virCharBitsToVirCharIndex[charBits]);
            }
            tileVirCharIndices = tileVirCharIndices.Distinct().ToList();
            tileVirCharIndices.Sort();

            _virCharIndicesPerTile.Add(tileVirCharIndices);
         }

         // Create (one-to-many) mapping from vir chars to vir chars primes.
         {
            int nextVirCharPrime = 0;

            for (int i = 0; i < _tiles.Count; ++i)
            {
               List<int> tileVirCharIndices = _virCharIndicesPerTile[i];
               List<int> tileVirCharPrimeIndices = new List<int>();

               if (InitVirPrimes(ref nextVirCharPrime, tileVirCharPrimeIndices, int.MaxValue, int.MinValue, tileVirCharIndices, 0, virCharPrimesPerVirChar))
               {
                  _virCharPrimesPerTile.Add(tileVirCharPrimeIndices);
               }
               else
               {
                  // Should never get here.
                  Debug.Assert(false, "Unable to allocate vir char primes for tile " + i);
               }
            }

            // Create resulting (many-to-one) mapping from vir char primes to vir chars.
            int[] virCharPerVirCharPrime = new int[nextVirCharPrime];
            for (int i = 0; i < _virChars.Count; ++i)
            {
               foreach (int j in virCharPrimesPerVirChar[i])
               {
                  virCharPerVirCharPrime[j] = i;
               }
            }

            _virCharPrimeToVirChar = virCharPerVirCharPrime.ToList();
         }
      }

      void InitVirTilePrimes()
      {
         // Each vir tile has a list of vir tile primes (duplicates of vir tile at different indices in the resulting vir tile prime list).
         List<List<int>> virTilePrimesPerVirTile = new List<List<int>>();

         // Start with empty list of vir tile primes per vir tile.
         for (int i = 0; i < _virTiles.Count; ++i)
         {
            virTilePrimesPerVirTile.Add(new List<int>());
         }

         int h = _map.GetLength(0);
         int w = _map.GetLength(1);

         // Create sorted list of unique vir tiles per map column.
         for (int j = 0; j < w; ++j)
         {
            List<int> virTiles = new List<int>();
            _virTilesPerMapColumn.Add(virTiles);

            for (int i = 0; i < h; ++i)
            {
               int virTileIndex = _map[i, j];
               virTiles.Add(virTileIndex);
            }

            virTiles = virTiles.Distinct().ToList();
            virTiles.Sort();
         }

         // Create (one-to-many) mapping from vir tiles to vir tile primes.
         {
            int nextVirTilePrime = 0;

            for (int j = 0; j < w; ++j)
            {
               List<int> virTiles = _virTilesPerMapColumn[j];
               List<int> virTilePrimes = new List<int>();

               if (InitVirPrimes(ref nextVirTilePrime, virTilePrimes, int.MaxValue, int.MinValue, virTiles, 0, virTilePrimesPerVirTile))
               {
                  _virTilePrimesPerMapColumn.Add(virTilePrimes);
               }
               else
               {
                  // Should never get here.
                  Debug.Assert(false, "Unable to allocate vir tile primes for map column " + j);
               }
            }

            // Create resulting (many-to-one) mapping from vir tile primes to vir tiles.
            int[] virTilePerVirTilePrime = new int[nextVirTilePrime];
            for (int i = 0; i < _virTiles.Count; ++i)
            {
               foreach (int j in virTilePrimesPerVirTile[i])
               {
                  virTilePerVirTilePrime[j] = i;
               }
            }

            _virTilePrimeToVirTile = virTilePerVirTilePrime.ToList();
         }
      }

      bool InitVirPrimes(
         ref int nextVirPrime,
         List<int> outVirPrimes, int minVirPrime, int maxVirPrime,
         List<int> inVirs, int inVirsIndex, List<List<int>> virPrimesPerVir)
      {
         // List of already allocated vir {chars, tiles} primes for this vir {char, tile}.
         List<int> virPrimes = virPrimesPerVir[inVirs[inVirsIndex]];

         // First try to use already allocated vir {char, tile} primes for this vir {char, tile}.
         for (int i = 0; i < virPrimes.Count; ++i)
         {
            int virPrime = virPrimes[i];
            int curMinVirPrime = Math.Min(virPrime, minVirPrime);
            int curMaxVirPrime = Math.Max(virPrime, maxVirPrime);

            if (curMaxVirPrime - curMinVirPrime <= VirPrimeMaxOffset)
            {
               // Try to use vir prime since it's within range.
               outVirPrimes.Add(virPrime);

               // Resolve remaining indices recursively.
               if ((inVirsIndex >= inVirs.Count - 1) || InitVirPrimes(ref nextVirPrime, outVirPrimes, curMinVirPrime, curMaxVirPrime, inVirs, inVirsIndex + 1, virPrimesPerVir))
               {
                  return true;
               }

               // Failed, remove it and try next.
               outVirPrimes.RemoveAt(outVirPrimes.Count - 1);
            }
         }

         // Failed to use existing vir primes.
         {
            // Allocate new vir prime.
            int virPrime = nextVirPrime++;
            int curMinVirPrime = Math.Min(virPrime, minVirPrime);
            int curMaxVirPrime = Math.Max(virPrime, maxVirPrime);

            if (curMaxVirPrime - curMinVirPrime <= VirPrimeMaxOffset)
            {
               virPrimes.Add(virPrime);
               outVirPrimes.Add(virPrime);

               // Resolve remaining indices recursively.
               if ((inVirsIndex >= inVirs.Count - 1) || InitVirPrimes(ref nextVirPrime, outVirPrimes, curMinVirPrime, curMaxVirPrime, inVirs, inVirsIndex + 1, virPrimesPerVir))
               {
                  return true;
               }

               // Failed, remove just added vir char prime.
               outVirPrimes.RemoveAt(outVirPrimes.Count - 1);
               virPrimes.RemoveAt(virPrimes.Count - 1);
            }

            // Failed, free allocated vir char prime.
            nextVirPrime--;
         }

         // Failed to resolve this vir, back-track.
         return false;
      }

      //

      int GetCharIndex(Char thisChar)
      {
         return _chars.FindIndex(x => x.Equals(thisChar));
      }

      int GetTileIndex(Tile tile)
      {
         return _tiles.FindIndex(x => x.Equals(tile));
      }

      static string ToBinary(int val, int len)
      {
         string binary = Convert.ToString(val, 2);
         while (binary.Length < len)
         {
            binary = "0" + binary;
         }

         return binary;
      }

      static bool IsHiresColor(int color)
      {
         return color < 8;
      }
   }
}