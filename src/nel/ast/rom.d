module nel.ast.rom;

static import std.string;
static import std.stdio;

import nel.report;

RomGenerator romGenerator;

class RomGenerator
{
    private:
        // Mapper number, as designated by the iNES header formate.
        uint mapper;
        // Number of 16K PRG ROM banks.
        uint prg;
        // Number of 8K CHR ROM banks.
        uint chr;
        // Nametable mirroring type (true = vertical / false = horizontal). Defaults to false (horizontal)
        bool mirroring;
        // Has save battery. Defaults to false.
        bool battery;
        // Provides support for four screens of nametables,
        // instead of the system's default of two. Defaults to false.
        bool fourscreen;
        
        // Whether or not the bank index has been specified.
        bool bankSet;
        // The bank of code to use, initialized upon first bank switch.
        uint activeBankIndex;
        // All 8K banks within the ROM. Initialized on construction.
        RomBank[] banks;
        
        // The position in RAM. Automatically incremented as variables are defined.
        bool ramCounterSet;
        uint ramCounter;
        
    public:
        this(uint mapper, uint prg, uint chr, bool mirroring, bool battery, bool fourscreen)
        {
            this.mapper = mapper;
            this.prg = prg;
            this.chr = chr; 
            this.mirroring = mirroring;
            this.battery = battery;
            this.fourscreen = fourscreen;
            bankSet = false;
            ramCounterSet = false;
            banks.length = prg * 2 + chr;
            for(uint i = 0; i < banks.length; i++)
            {
                banks[i] = new RomBank();
            }
        }
        
        /**
         * Clears the ROM's positional info like the active bank, and resets all banks.
         * This should be called at the start of a new semantic pass.
         */
        void resetRomPosition()
        {
            foreach(i, bank; banks)
            {
                bank.resetPosition();
            }
            bankSet = false;
        }
        
        /**
         * Switches to a new bank, and sets its origin. 
         * At least one switch must occur before program code appears.
         */
        void switchBank(uint bankIndex, SourcePosition sourcePosition)
        {
            if(bankIndex < 0 || bankIndex >= banks.length)
            {
                error(std.string.format("bank index %s is outside of range 0..%s.", bankIndex, banks.length - 1), sourcePosition, true);
            }
            else
            {
                bankSet = true;
                activeBankIndex = bankIndex;
            }
        }
        
        RomBank getActiveBank()
        {
            return bankSet ? banks[activeBankIndex] : null;
        }
        
        RomBank checkActiveBank(string construct, SourcePosition position)
        {
            RomBank bank = getActiveBank();
            if(bank is null)
            {
                error(construct ~ " found, but a rom bank hasn't been selected yet.", position, true);
                return null;
            }
            else
            {
                if(!bank.hasOrigin())
                {
                    error(construct ~ " found before the rom location in the current bank was set.", position, true);
                    return null;
                }
                else
                {
                    return bank;
                }
            }
        }
        
        bool isRamCounterSet()
        {
            return ramCounterSet;
        }
        
        uint getRamCounter()
        {
            return ramCounterSet ? ramCounter : 0xDEADFACE;
        }
        
        void moveRam(uint position)
        {
            ramCounterSet = true;
            ramCounter = position;
        }
        
        /**
         * Reserve RAM storage for a variable. Increments ram counter accordingly.
         * Error if RAM counter is uninitialized.
         */
        bool expandRam(uint size, SourcePosition sourcePosition)
        {
            if(ramCounter + size > 65536)
            {
                error(std.string.format("ram counter goes past addressable memory 0..65536 by %s bytes", ramCounter + size - 65536), sourcePosition, true);
                return false;
            }
            else
            {
                ramCounter += size;
                return true;
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
        
        void dumpRaw(std.stdio.File file)
        {
            // Based on info at http://wiki.nesdev.com/w/index.php/INES
            ubyte[16] header = [
                // 0..3: Write "NES" followed by MS-DOS end-of-file marker.
                0x4E, 0x45, 0x53, 0x1A,
                // 4: Number of 16K PRG ROM banks
                cast(ubyte) prg,
                // 5: Number of 8K CHR ROM banks, 0 means this cart has CHR RAM.
                cast(ubyte) chr,
                // 6: Write the "Flags 6" byte, skip the 'trainer' flag for now.
                cast(ubyte) ((mirroring != 0) | (battery << 1) | (fourscreen << 3) | ((mapper & 0xF) << 4)),
                // 7: Write the "Flags 7" byte, just the mapper part though.
                cast(ubyte) (mapper >> 4),
                // 8: Number of 8K PRG RAM banks -- for now just write a 0, which implies 8KB PRG RAM at most.
                0,
                // 9..15: Ignore other flag fields. Zero-pad this header to 16 bytes.
                0, 0, 0, 0, 0, 0, 0
            ];
            
            file.rawWrite(header);
            
            // Now write everything else.
            foreach(i, bank; banks)
            {
                bank.dumpRaw(file);
            }
        }
}

class RomBank
{
    private:
        // Size of each ROM bank.
        static immutable uint BANK_SIZE = 8192;
        // Value used to pad unused bank space.
        static immutable ubyte PAD_VALUE = 0xFF;
    public:
        // Until a ROM relocation occurs, this page has no origin.
        bool originSet;
        // Origin point as an absolute memory address where this bank starts.
        uint origin;
        // The position, in bytes, into the bank.
        uint position;
        // The reserved amount of bytes in this bank, used to
        // error-check bank overflows, and to some extent,
        // to prevent discrepencies between predicted size and actual size.
        uint reservedSize;
        // The byte data held by this bank.
        ubyte data[BANK_SIZE];
        
        this()
        {
            originSet = false;
            position = 0;
            reservedSize = 0;
            data[] = PAD_VALUE;
        }
        
        /**
         * Returns whether or not this ROM bank's origin is initialized.
         */
        bool hasOrigin()
        {
            return originSet;
        }
        
        /**
         * Returns the current position within the ROM bank.
         * This is a number in the range 0..8191.
         */
        uint getPosition()
        {
            return originSet ? position : 0x12345678;
        }
        
        /**
         * Returns the current value of the program counter,
         * within this bank, within address space 0..65535.
         */
        uint getProgramCounter()
        {
            return originSet ? origin + position : 0xDEAAAAAD;
        }
        
        void resetPosition()
        {
            position = 0;
        }
        
        
        void expand(uint amount, SourcePosition sourcePosition)
        {
            if(origin + position + amount > 65536)
            {
                error(std.string.format("bank's position went outside of addressable memory 0..65535"
                    ~ "(attempted to expand to position = %s)", origin + position + amount), sourcePosition, true);
                return;
            }
            
            reservedSize += amount;
            position += amount;
            
            if(!originSet)
            {
                error("no origin point was set before bank was expanded.", sourcePosition, true);
            }
            if(reservedSize > BANK_SIZE)
            {
                error(std.string.format("bank expanded beyond its %s byte boundary by %s bytes",
                    BANK_SIZE, reservedSize - BANK_SIZE), sourcePosition, true);
            }
        }

        void org(uint pos, SourcePosition sourcePosition)
        {
            if(originSet)
            {
                if(pos < origin + position)
                {
                    error(std.string.format("attempt to move backwards within the bank. (location %s -> %s)",
                        origin + position, pos), sourcePosition, true);
                }
                else
                {   
                    expand(pos - (origin + position), sourcePosition);
                }
            }
            else
            {
                origin = pos;
                originSet = true;
            }
        }
        
        void seekPosition(uint pos, SourcePosition sourcePosition)
        {
            if(pos > origin + reservedSize)
            {
                dumpDebug(std.stdio.stdout);
                error("attempt to move outside of bank's reserved space.", sourcePosition, true);
            }
            else
            {        
                // Seek to new location.
                position = pos - origin;
            }
        }
        
        
        void writeByte(uint value, SourcePosition sourcePosition)
        {
            if(position >= reservedSize)
            {
                dumpDebug(std.stdio.stdout);
                error("attempt to write outside of bank's reserved space.", sourcePosition, true);
            }
            else if(value > 255)
            {
                error(
                    std.string.format(
                        "value %s is outside of representable 8-bit range 0..255", value
                    ), sourcePosition
                );
            }
            else
            {
                data[position++] = value & 0xFF;
            }
        }

        void writeWord(uint value, SourcePosition sourcePosition)
        {
            if(position >= reservedSize)
            {
                error("attempt to write outside of bank's reserved space.", sourcePosition, true);
            }
            else if(value > 65535)
            {
                error(
                    std.string.format(
                        "value %s is outside of representable 16-bit range 0..65535", value
                    ), sourcePosition
                );
            }
            else
            {
                // Write word in little-endian order.
                data[position++] = value & 0xFF;
                data[position++] = (value >> 8) & 0xFF;
            }
        }
        
        void dumpDebug(std.stdio.File file)
        {
            std.stdio.writefln("origin: %s - position: %s - reserved: %s / %s", origin, position, reservedSize, BANK_SIZE);
            
            immutable int PER_ROW = 32;
            
            for(uint i = 0; i < BANK_SIZE / PER_ROW; i++)
            {
                for(uint j = 0; j < PER_ROW; j++)
                {
                    std.stdio.writef("0x%02X ", data[i * PER_ROW + j]);
                }
                std.stdio.writeln("");
            }
            std.stdio.writeln("");
            std.stdio.writeln("--------");
            std.stdio.writeln("");
        }
        
        void dumpRaw(std.stdio.File file)
        {
            file.rawWrite(data);
        }
}