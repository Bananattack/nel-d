module nel.ast.variable_declaration;

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
import nel.ast.statement;
import nel.ast.definition;
import nel.ast.expression;
import nel.ast.storage_type;
import nel.ast.symbol_table;

class VariableDeclaration : Statement
{
    private:
        string[] names;
        StorageType storageType;
        Expression arraySize;
        
    public:
        this(string[] names, StorageType storageType, Expression arraySize, SourcePosition position)
        {
            super(StatementType.VARIABLE, position);
            this.names = names;
            this.storageType = storageType;
            this.arraySize = arraySize;
        }
        
        void aggregate()
        {
            uint size = storageType == StorageType.WORD ? 2 : 1;
            
            if(arraySize)
            {
                if(!arraySize.fold(true, false))
                {
                    error("could not resolve the array size provided to this variable declaration", getPosition());
                    return;
                }
                else
                {
                    if(arraySize.getFoldedValue() == 0)
                    {
                        error("an array size of 0 is invalid. why ask for a variable that can hold nothing?", arraySize.getPosition());
                        return;
                    }
                    else
                    {
                        size *= arraySize.getFoldedValue();
                    }
                }
            }
            
            if(!romGenerator.isRamCounterSet())
            {
                error("variable declaration was found before the ram location was set.", getPosition(), true);
            }
            
            foreach(i, name; names)
            {
                // Insert symbol, using current RAM counter value as var offset.
                getActiveTable().put(new VariableDefinition(name, this, romGenerator.getRamCounter(), getPosition()));
                
                // Reserve size bytes in RAM counter to advance it forward.
                romGenerator.expandRam(size, getPosition());
            }
        }
        
        void validate()
        {
        }
        
        void generate()
        {
        }
}