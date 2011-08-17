module nel.ast.builtin;

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

import nel.ast.argument;

enum BuiltinInstruction
{
    NONE,
    // These have a receiver and require some sort of immediate/memory argument (error if there is none)
    GET,    // get command. Transfer a value from the argument into the receiver. 
    PUT,    // put command. Transfers a value from the receiver into the argument. 
    ADD,    // add command. Synthetic instruction to add without carry. 
    ADDC,   // addc command. Adds with carry. 
    SUB,    // subtract command. Synthetic instruction to subtract without carry. 
    SUBC,   // subc command. Subtract with carry (1 - borrow) command. 
    OR,     // or command. Bitwise OR between receiver and argument. 
    AND,    // and command. Bitwise AND between receiver and argument. 
    XOR,    // xor command. Bitwise XOR between receiver and argument. 
    CMP,    // cmp command. Compares the argument to the receiver. 
    BIT,    // bit command. Does a weird bitwise test between receiver and argument. 
    // These have a receiver but no argument
    INC,    // inc command. Increments receiver. 
    DEC,    // dec command. Decrements receiver. 
    NOT,    // not command. Synthetic instruction to bitwise NOT the receiver. 
    NEG,    // neg command. Synthetic instruction to do arithmetic 2's complement negation. 
    SHL,    // shl command. Logically shifts the receiver left by one bit. 
    SHR,    // shl command. Logically shifts the receiver right by one bit. 
    ROL,    // rol command. Rotates the receiver left by one bit through carry. 
    ROR,    // ror command. Rotates the receiver right by one bit through carry. 
    PUSH,   // push command. Pushes receiver onto stack. 
    PULL,   // pull command. Pulls receiver from stack. 
    // These have P as a receiver, and require a p-flag argument (error if there is none)
    SET,    // set command. Turns on a p-flag. 
    UNSET   // unset command. Turns on a p-flag. 
}

private ArgumentType[string] registers;
private ArgumentType[string] flags;
private BuiltinInstruction[string] instructions;
private string[BuiltinInstruction] instructionNames;

static this()
{
    registers = [
        "a": ArgumentType.A,
        "x": ArgumentType.X,
        "y": ArgumentType.Y,
        "s": ArgumentType.S,
        "p": ArgumentType.P
    ];
    
    flags = [
        "zero": ArgumentType.ZERO,
        "negative": ArgumentType.NEGATIVE,
        "overflow": ArgumentType.OVERFLOW,
        "carry": ArgumentType.CARRY,
        "decimal": ArgumentType.DECIMAL,
        "interrupt": ArgumentType.INTERRUPT
    ];
    
    instructions = [
        "get": BuiltinInstruction.GET,
        "put": BuiltinInstruction.PUT,
        "add": BuiltinInstruction.ADD,
        "addc": BuiltinInstruction.ADDC,
        "sub": BuiltinInstruction.SUB,
        "subc": BuiltinInstruction.SUBC,
        "or": BuiltinInstruction.OR,
        "and": BuiltinInstruction.AND,
        "xor": BuiltinInstruction.XOR,
        "cmp": BuiltinInstruction.CMP,
        "bit": BuiltinInstruction.BIT,
        "inc": BuiltinInstruction.INC,
        "dec": BuiltinInstruction.DEC,
        "not": BuiltinInstruction.NOT,
        "neg": BuiltinInstruction.NEG,
        "shl": BuiltinInstruction.SHL,
        "shr": BuiltinInstruction.SHR,
        "rol": BuiltinInstruction.ROL,
        "ror": BuiltinInstruction.ROR,
        "push": BuiltinInstruction.PUSH,
        "pull": BuiltinInstruction.PULL,
        "set": BuiltinInstruction.SET,
        "unset": BuiltinInstruction.UNSET
    ];
    
    instructionNames[BuiltinInstruction.NONE] = "(none)";
    foreach(name, instruction; instructions)
    {
        instructionNames[instruction] = name;
    }
}

ArgumentType findBuiltinRegister(string text)
{
    ArgumentType* match = text in registers;
    return match is null ? ArgumentType.NONE : *match;
}

ArgumentType findBuiltinFlag(string text)
{
    ArgumentType* match = text in flags;
    return match is null ? ArgumentType.NONE : *match;
}

BuiltinInstruction findBuiltinInstruction(string text)
{
    BuiltinInstruction* match = text in instructions;
    return match is null ? BuiltinInstruction.NONE : *match;
}

string getBuiltinInstructionName(BuiltinInstruction value)
{
    string* match = value in instructionNames;
    return match is null ? "" : instructionNames[value];
}