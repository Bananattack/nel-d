module nel.ast.branch_statement;

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

import nel.report;
import nel.ast.rom;
import nel.ast.node;
import nel.ast.argument;
import nel.ast.statement;

enum BranchType
{
    GOTO,
    CALL,
    RETURN,
    RESUME,
    NOP
}

class BranchStatement : Statement
{
    private:
        BranchType branchType;
        Argument destination;
        BranchCondition condition;
        
    public:
        this(BranchType branchType, SourcePosition position)
        {
            super(StatementType.BRANCH, position);
            this.branchType = branchType;
        }
        
        this(BranchType branchType, Argument destination, SourcePosition position)
        {
            this(branchType, position);
            this.destination = destination;
        }
        
        this(BranchType branchType, Argument destination, BranchCondition condition, SourcePosition position)
        {
            this(branchType, destination, position);
            this.condition = condition;
        }
        
        void aggregate()
        {
        }
        
        void validate()
        {
            uint size = 0;
            switch(branchType)
            {
                case BranchType.NOP:
                case BranchType.RETURN:
                case BranchType.RESUME:
                    // Implicit operand.
                    size = 1;
                    break;
                case BranchType.GOTO:
                    // Conditional goto has relative offset -128..127, regular goto is absolute 16-bit address.
                    size = condition is null ? 3 : 2;
                    break;
                case BranchType.CALL:
                    // Absolute 16-bit location.
                    size = 3;
                    break;
            }
            
            // Reserve the bytes needed for this data.
            RomBank bank = romGenerator.checkActiveBank("branch statement", getPosition());
            if(bank !is null)
            {
                bank.expand(size, getPosition());
            }
        }
        
        void generate()
        {
            // Get the bank to use for writing.
            RomBank bank = romGenerator.checkActiveBank("branch statement", getPosition());
            if(bank is null)
            {
                return;
            }
        
            switch(branchType)
            {
                case BranchType.NOP:
                    bank.writeByte(0xEA, getPosition()); // nop
                    break;
                case BranchType.RETURN:
                    bank.writeByte(0x60, getPosition()); // rts
                    break;
                case BranchType.RESUME:
                    bank.writeByte(0x40, getPosition()); // rti
                    break;
                case BranchType.GOTO:
                    if(condition)
                    {
                        uint opcode = 0;
                        if(destination.getArgumentType() == ArgumentType.INDIRECT)
                        {
                            error("goto [indirect] cannot have a 'when' clause.", getPosition());
                        }
                        switch(condition.getFlag().getArgumentType())
                        {
                            case ArgumentType.CARRY:
                                // bcs / bcc
                                opcode = !condition.isNegated() ? 0xB0 : 0x90;
                                break;
                            case ArgumentType.ZERO:
                                // beq / bne
                                opcode = !condition.isNegated() ? 0xF0 : 0xD0;
                                break;
                            case ArgumentType.NEGATIVE:
                                // bmi / bpl
                                opcode = !condition.isNegated() ? 0x30 : 0x10;
                                break;                        
                            case ArgumentType.OVERFLOW:
                                // bvs / bvc
                                opcode = !condition.isNegated() ? 0x70 : 0x50;
                                break;
                            default:
                                error("goto condition provided must be 'carry', 'zero', 'negative', or 'overflow'", getPosition());
                        }
                        bank.writeByte(opcode, getPosition());
                        destination.writeRelativeByte(bank);
                    }
                    else
                    {
                        uint opcode = 0;
                        switch(destination.getArgumentType())
                        {
                            case ArgumentType.DIRECT:
                                opcode = 0x4C; // jmp label
                                break;
                            case ArgumentType.INDIRECT:
                                opcode = 0x6C; // jmp [indirect]
                                break;
                        }
                        
                        bank.writeByte(opcode, getPosition());
                        destination.write(bank);
                    }
                    break;
                case BranchType.CALL:
                    if(destination.getArgumentType() == ArgumentType.INDIRECT)
                    {
                        error("'call' cannot take an [indirect] memory location.", getPosition());
                    }
                    bank.writeByte(0x20, getPosition()); // jsr label
                    destination.write(bank);
                    break;
            }
        }
}

class BranchCondition : Node
{
    private:
        bool negated;
        Argument flag;
    
    public:
        this(bool negated, Argument flag, SourcePosition position)
        {
            super(position);
            this.negated = negated;
            this.flag = flag;
        }
        
        Argument getFlag()
        {
            return flag;
        }
        
        bool isNegated()
        {
            return negated;
        }
        
}