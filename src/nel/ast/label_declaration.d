module nel.ast.label_declaration;

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
import nel.ast.symbol_table;

class LabelDeclaration : Statement
{
    private:
        string name;
        LabelDefinition definition;
        
    public:
        this(string name, SourcePosition position)
        {
            super(StatementType.LABEL, position);
            this.name = name;
            this.definition = null;
        }
        
        void aggregate()
        {
            definition = new LabelDefinition(name, this, getPosition());
            getActiveTable().put(definition);
        }
        
        void validate()
        {
            RomBank bank = romGenerator.getActiveBank();
            if(bank is null)
            {
                error("label declaration found, but a rom bank hasn't been selected yet.", getPosition(), true);
            }
            else
            {
                if(bank.hasOrigin())
                {
                    definition.setOffset(bank.getProgramCounter());
                }
                else
                {
                    error("label declaration was found before the rom location in the current bank was set.", getPosition(), true);
                }
            }
        }
        
        void generate()
        {
        }
}