module nel.ast.bank;

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

enum BankType
{
    NONE,
    RAM,    // RAM bank for reserving memory addresses with no actual space in ROM.
    PRG,    // PRG ROM bank for program code and data.
    CHR     // CHR ROM bank for tile graphics.
}

class Bank
{
    public:
        // Value used to pad unused bank space.
        static immutable ubyte PAD_VALUE = 0xFF;
        
    private:
        // The type of the bank.
        BankType bankType;
        // Where this bank was defined.
        SourcePosition sourcePosition;
        // Until a ROM relocation occurs, this page has no origin.
        bool originSet;
        // Origin point as an absolute memory address where this bank starts.
        uint origin;
        // The position, in bytes, into the bank.
        uint position;
        // The total size of this bank, used to prevent write overflows, and possibly calculate space in the ROM.
        uint bankSize;
        // The byte data held by this bank.
        ubyte[] data;
    
        void reserve(uint size, SourcePosition sourcePosition)
        {
            if(position + size > bankSize)
            {
                error(
                    std.string.format(
                        "bank expanded beyond its %s byte boundary by %s byte(s)",
                        bankSize, position + size - bankSize
                    ),
                    sourcePosition, true
                );
            }
            else
            {
                position += size;
            }        
        }
    
    public:
        this(BankType bankType, uint bankSize, SourcePosition sourcePosition)
        {
            this.bankType = bankType;
            this.bankSize = bankSize;
            this.sourcePosition = sourcePosition;
            
            originSet = false;
            position = 0;
            
            if(bankType != BankType.RAM)
            {
                data = new ubyte[bankSize];
                data[] = PAD_VALUE;
            }
        }
        
        SourcePosition getSourcePosition()
        {
            return sourcePosition;
        }
        
        bool hasOrigin()
        {
            return originSet;
        }
        
        void resetPosition()
        {
            position = 0;
            originSet = false;
        }
        
        uint getSize()
        {
            return bankSize;
        }
        
        BankType getBankType()
        {
            return bankType;
        }
        
        /**
         * Returns the current position within the bank.
         * This is a number in the range 0..size.
         * If the origin has not yet been set, the return value is undefined.
         */
        uint getRelativePosition()
        {
            return originSet ? position : 0xFACEBEEF;
        }

        /**
         * Returns the absolute position, in the address space 0..65535.
         * If the origin has not yet been set, the return value is undefined.
         */
        uint getAbsolutePosition()
        {
            return originSet ? origin + position : 0xFACEBEEF;
        }
        
        /**
         * Reserve RAM storage for a variable. Increments position accordingly.
         * Error if origin is uninitialized, or this bank isn't RAM.
         */
        void reserveRam(uint size, SourcePosition sourcePosition)
        {
            if(bankType == BankType.RAM)
            {
                reserve(size, sourcePosition);
            }
            else
            {
                error("variable storage cannot be defined in a ROM bank", sourcePosition, true);
            }
        }
        
        /**
         * Reserve ROM storage for data/code. Increments position accordingly.
         * Error if origin is uninitialized, or this bank is not ROM.
         */
        void reserveRom(uint size, SourcePosition sourcePosition)
        {
            if(bankType == BankType.RAM)
            {
                error("data cannot be written to a RAM bank", sourcePosition, true);
            }
            else
            {
                reserve(size, sourcePosition);
            }
        }
        
        /**
         * Write a byte to ROM. Error if this bank is not ROM.
         */
        void writeByte(uint value, SourcePosition sourcePosition)
        {
            if(bankType == BankType.RAM)
            {
                error("data cannot be written to a RAM bank", sourcePosition, true);
            }
            else if(position >= bankSize)
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

        /**
         * Write a 2-byte word to ROM. Error if this bank is not ROM.
         */        
        void writeWord(uint value, SourcePosition sourcePosition)
        {
            if(bankType == BankType.RAM)
            {
                error("data cannot be written to a RAM bank", sourcePosition, true);
            }
            else if(position >= bankSize)
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
        
        void setAbsolutePosition(uint dest, SourcePosition sourcePosition)
        {
            if(originSet)
            {
                if(dest < origin + position)
                {
                    error(
                        std.string.format(
                            "attempt to move backwards within the bank. (location %s -> %s)",
                            origin + position, dest
                        ), sourcePosition, true
                    );
                }
                else
                {   
                    reserve(dest - (origin + position), sourcePosition);
                }
            }
            else
            {
                if(dest + bankSize > 65536)
                {
                    error(
                        std.string.format(
                            "a bank with start location %s and size %s has an invalid upper bound %s, outside of addressable memory 0..65535.",
                            dest, bankSize, dest + bankSize
                        ), sourcePosition, true
                    );                
                }
                origin = dest;
                originSet = true;
            }
        }
        
        void dumpDebug(std.stdio.File file)
        {
            std.stdio.writefln("origin: %s - position: %s - size: %s", origin, position, bankSize);
         
            if(bankType == BankType.RAM)
            {
                std.stdio.writefln("(ram bank)", origin, position, bankSize);
            }
            else
            {
                std.stdio.writefln("(rom bank)", origin, position, bankSize);
            
                immutable int PER_ROW = 32;
                
                for(uint i = 0; i < bankSize / PER_ROW; i++)
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
        }
        
        void dumpRaw(std.stdio.File file)
        {
            if(bankType != BankType.RAM)
            {
                file.rawWrite(data);
            }
        }
}