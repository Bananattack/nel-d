module nel.ast.statement;

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
import nel.ast.node;

enum StatementType
{
    BLOCK,                  // A compound block statement, used for scoping. 
    HEADER,                 // A header statement. 
    RELOCATION,             // A relocation statement, used to move the ROM and RAM positions. 
    LABEL,                  // A label declaration. 
    CONSTANT,               // A constant declaration. 
    VARIABLE,               // A variable declaration. 
    DATA,                   // A data statement. 
    COMMAND,                // A command statement. 
    BRANCH,                 // A branching statement, like goto, call or return. 
    EMBED,                  // A point to embed a binary file. 
    ENUM,                   // An enumeration declaration.
    IF,                     // An if statement.
};

abstract class Statement : Node
{
    private:
        StatementType statementType;
        
    public:
        this(StatementType statementType, SourcePosition position)
        {
            super(position);
            this.statementType = statementType;
        }
        
        StatementType getStatementType()
        {
            return statementType;
        }
        
        abstract void aggregate();
        abstract void validate();
        abstract void generate();
}