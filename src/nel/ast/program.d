module nel.ast.program;

// Copyright (C) 2011 by Andrew G. Crowell
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//  
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

static import std.stdio;
static import std.string;

import nel.report;
import nel.ast.bank;

// The global program instance
Program program;

class Program
{
    private:
        // Mapper number, as designated by the iNES header formate.
        uint mapper;
        // Nametable mirroring type (true = vertical / false = horizontal). Defaults to false (horizontal)
        bool mirroring;
        // Has save battery. Defaults to false.
        bool battery;
        // Provides support for four screens of nametables,
        // instead of the system's default of two. Defaults to false.
        bool fourscreen;
        
        // The currently active program bank.
        Bank activeBank;
        // All banks within the program.
        Bank[] banks;
        // A lookup table of bank name to bank.
        Bank[string] bankTable;
        
    public:
        this(uint mapper, bool mirroring, bool battery, bool fourscreen)
        {
            this.mapper = mapper;
            this.mirroring = mirroring;
            this.battery = battery;
            this.fourscreen = fourscreen;
            
            activeBank = null;
        }
        
        /**
         * Clears this program's positional info like the active bank, and resets all bank positions.
         * This should be called at the start of a new semantic pass.
         */
        void resetPosition()
        {
            foreach(i, bank; banks)
            {
                bank.resetPosition();
            }
            activeBank = null;
        }
        
        /**
         * Defines a new bank. It is an error to redefine a bank.
         */
        void defineBank(BankType bankType, string name, uint size, SourcePosition position)
        {
            Bank* match = name in bankTable;
            if(match is null)
            {
                Bank bank = new Bank(bankType, size, position);
                bankTable[name] = bank;
                banks ~= bank;
            }
            else
            {
                error("redefinition of bank '" ~ name ~ "' (previously defined at " ~ (*match).getSourcePosition().toString() ~ ")", position, true);
            }
        }
        
        /**
         * Switches to a new bank, and sets its origin. 
         * A switch to ROM must occur before program code appears.
         * It is an error to reference an undefined bank.
         */
        void switchBank(string name, SourcePosition sourcePosition)
        {
            Bank* match = name in bankTable;
            if(match is null)
            {
                error(std.string.format("could not resolve bank '%s' used in relocation statement.", name), sourcePosition, true);
            }
            else
            {
                activeBank = *match;
            }
        }
        
        Bank getActiveBank()
        {
            return activeBank;
        }
        
        Bank checkActiveBank(string construct, SourcePosition position)
        {
            Bank bank = getActiveBank();
            if(bank is null)
            {
                error(construct ~ " found, but a bank hasn't been selected yet.", position, true);
                return null;
            }
            else
            {
                if(!bank.hasOrigin())
                {
                    error(construct ~ " found before a location in the current bank was set.", position, true);
                    return null;
                }
                else
                {
                    return bank;
                }
            }
        }
        
        void dumpDebug(std.stdio.File file)
        {
            foreach(i, bank; banks)
            {
                file.writeln(std.string.format("-- bank %s --", i));
                bank.dumpDebug(file);
            }
        }
        
        void save(std.stdio.File file)
        {
            uint prg = 0;
            uint chr = 0;
            foreach(i, bank; banks)
            {
                switch(bank.getBankType())
                {
                    case BankType.PRG:
                        prg += bank.getSize();
                        break;
                    case BankType.CHR:
                        chr += bank.getSize();
                        break;
                    default:
                        break;
                }
            }
            
            // Make the closest 16K and 8K multiples for PRG and CHR respectively.
            // These are necessary for satisfying the iNES format.
            uint prgUpper = ((prg + 16383) / 16384) * 16384;
            uint chrUpper = ((chr + 8191) / 8192) * 8192;
            
            // Based on info at http://wiki.nesdev.com/w/index.php/INES
            ubyte[16] header = [
                // 0..3: "NES" followed by MS-DOS end-of-file marker.
                0x4E, 0x45, 0x53, 0x1A,
                // 4: Number of 16K PRG ROM banks
                cast(ubyte) (prgUpper / 16384),
                // 5: Number of 8K CHR ROM banks, if this has none, then this cart has CHR RAM.
                cast(ubyte) (chrUpper / 8192),
                // 6: The "Flags 6" byte, skip the 'trainer' flag for now.
                cast(ubyte) ((mirroring != 0) | (battery << 1) | (fourscreen << 3) | ((mapper & 0xF) << 4)),
                // 7: The "Flags 7" byte, just the mapper part though.
                cast(ubyte) (mapper >> 4),
                // 8: Number of 8K PRG RAM banks -- for now just write a 0, which implies 8KB PRG RAM at most.
                0,
                // 9..15: Ignore other flag fields. Zero-pad this header to 16 bytes.
                0, 0, 0, 0, 0, 0, 0
            ];
            
            file.rawWrite(header);
            
            ubyte[] padding;
            
            // Write PRG.
            foreach(i, bank; banks)
            {
                if(bank.getBankType() == BankType.PRG)
                {
                    bank.dumpRaw(file);
                }
            }
            // Pad the missing remainder.
            padding = new ubyte[prgUpper - prg];
            padding[] = Bank.PAD_VALUE;
            if(padding.length)
            {
                file.rawWrite(padding);
            }

            // Write CHR.
            foreach(i, bank; banks)
            {
                if(bank.getBankType() == BankType.CHR)
                {
                    bank.dumpRaw(file);
                }
            }
            // Pad the missing remainder.
            padding = new ubyte[chrUpper - chr];
            padding[] = Bank.PAD_VALUE;
            if(padding.length)
            {
                file.rawWrite(padding);
            }
        }
}