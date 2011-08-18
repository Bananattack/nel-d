module nel.ast.argument;

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

static import std.string;

import nel.report;
import nel.ast.bank;
import nel.ast.node;
import nel.ast.builtin;
import nel.ast.program;
import nel.ast.expression;

enum ArgumentType
{
    NONE,
    A,                      // The accumulator a
    X,                      // The index register x
    Y,                      // The index register y
    S,                      // The stack pointer s
    P,                      // The processor flags p
    ZERO,                   // The zero flag. Used to indicate when a value is zero.
    NEGATIVE,               // The negative flag. Used to indicate when a number is negative (2's complement).
    OVERFLOW,               // The overflow flag. Indicates when an overflow in a 2's complement value occurred.
    CARRY,                  // The carry flag. For multiple purposes: a carry for addition, a borrow for subtraction, a 9th shift bit.
    DECIMAL,                // The decimal flag. Used for binary coded decimal arithmetic, and is typically disabled since the 2A03 lacks BCD support.
    INTERRUPT,               // The interrupt disable flag. Used to prevent IRQs from occuring.
    IMMEDIATE,              // Immediate literal value.
    DIRECT,                 // Direct memory term.
    INDEXED_BY_X,           // Indexes a direct memory term by x.
    INDEXED_BY_Y,           // Indexes a direct memory term by y.
    INDIRECT,               // Indirectly addresses a value retreived from absolute memory (labels only).
    INDEXED_BY_X_INDIRECT,  // Indirectly addresses a value retreived by indexing the zero page.
    INDIRECT_INDEXED_BY_Y,  // Indexes a location that is indirectly addressesed by a value in the zero page.
}

string getArgumentDescription(ArgumentType value)
{
    switch(value)
    {
        case ArgumentType.NONE: return "none";
        case ArgumentType.A: return "register 'a'";
        case ArgumentType.X: return "register 'x'";
        case ArgumentType.Y: return "register 'y'";
        case ArgumentType.S: return "register 's'";
        case ArgumentType.P: return "register 'p'";
        case ArgumentType.ZERO: return "flag 'zero'";
        case ArgumentType.NEGATIVE: return "flag 'negative'";
        case ArgumentType.OVERFLOW: return "flag 'overflow'";
        case ArgumentType.CARRY: return "flag 'carry'";
        case ArgumentType.DECIMAL: return "flag 'decimal'";
        case ArgumentType.INTERRUPT: return "flag 'interrupt'";
        case ArgumentType.IMMEDIATE: return "immediate value";
        case ArgumentType.DIRECT: return "direct memory term";
        case ArgumentType.INDEXED_BY_X: return "direct indexed by x";
        case ArgumentType.INDEXED_BY_Y: return "direct indexed by y";
        case ArgumentType.INDIRECT: return "indirect memory term";
        case ArgumentType.INDEXED_BY_X_INDIRECT: return "indexed by x indirect";
        case ArgumentType.INDIRECT_INDEXED_BY_Y: return "indirect indexed by y";
        default: return "(???)";
    }
}

class Argument : Node
{
    private:
        ArgumentType argumentType;
        Expression expression;
        bool zeroPage;
        
    public:
        this(ArgumentType argumentType, SourcePosition position)
        {
            super(position);
            this.argumentType = argumentType;
            this.zeroPage = false;
        }
        
        this(ArgumentType argumentType, Expression expression, SourcePosition position)
        {
            super(position);
            this.argumentType = argumentType;
            this.expression = expression;
            this.zeroPage = false;
        }
        
        ArgumentType getArgumentType()
        {
            return argumentType;
        }
        
        bool isMemoryTerm()
        {
            switch(argumentType)
            {
                case ArgumentType.IMMEDIATE:
                case ArgumentType.DIRECT:
                case ArgumentType.INDEXED_BY_X:
                case ArgumentType.INDEXED_BY_Y:
                case ArgumentType.INDEXED_BY_X_INDIRECT:
                case ArgumentType.INDIRECT_INDEXED_BY_Y:
                    return true;
                default:
                    return false;
            }
        }
        
        void checkForZeroPage()
        {
            // Check if the expression uses defined symbols, and if possible can be used in zero-page addressing.
            // If the value is defined but unknown at this pass, assume it won't fit in zero page and don't error.
            if(expression !is null && expression.fold(false, true))
            {
                zeroPage = expression.getFoldedValue() < 256;
            }
        }
        
        bool isZeroPage()
        {
            return zeroPage;
        }

        void forceZeroPage()
        {
            // Force the argument to be zero-page.
            zeroPage = true;
        }
        
        void write(Bank bank)
        {
            // Only write data if there is an expression.
            if(expression !is null)
            {
                if(expression.fold(true, true))
                {
                    if(zeroPage)
                    {
                        bank.writeByte(expression.getFoldedValue(), getPosition());
                    }
                    else
                    {
                        bank.writeWord(expression.getFoldedValue(), getPosition());
                    }
                    
                }
                else
                {
                    error("argument could not be resolved", getPosition());
                }
            }
        }
        
        void writeRelativeByte(Bank bank)
        {
            // Only write data if there is an expression.
            if(expression)
            {
                if(expression.fold(true, true))
                {
                    // offset is the amount to add to the PC to reach the destination location.
                    int offset = cast(int) expression.getFoldedValue() - cast(int) (bank.getAbsolutePosition() + 1);
                    ubyte ofs = cast(ubyte) offset;
                    
                    if(offset >= -128 && offset <= 127)
                    {
                        bank.writeByte(ofs, getPosition());
                    }
                    else
                    {
                        error(
                            std.string.format(
                                "relative jump is outside of range -128..127 bytes. "
                                ~ "rewrite the branch or shorten the gaps in your code. "
                                ~ "(pc = %s, dest = %s, pc - dest = %s)",
                                bank.getAbsolutePosition(), expression.getFoldedValue(), offset
                            ), getPosition()
                        );
                    }
                }
                else
                {
                    error("argument could not be resolved", getPosition());
                }
            }
        }
}
