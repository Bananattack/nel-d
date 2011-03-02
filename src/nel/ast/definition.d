module nel.ast.definition;

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
import nel.ast.symbol_table;
import nel.ast.label_declaration;
import nel.ast.constant_declaration;
import nel.ast.variable_declaration;

enum DefinitionType
{
    NONE,
    VARIABLE,
    CONSTANT,
    LABEL,
    PACKAGE,
}

class Definition
{
    private:
        DefinitionType definitionType;        
        string name;
        SourcePosition position;
        
    public:        
        this(DefinitionType definitionType, string name, SourcePosition position)
        {
            this.definitionType = definitionType;
            this.name = name;
            this.position = position;
        }

        DefinitionType getDefinitionType()
        {
            return definitionType;
        }

        SourcePosition getPosition()
        {
            return position;
        }
        
        string getName()
        {
            return name;
        }
}

class LabelDefinition : Definition
{
    private:
        LabelDeclaration declaration;
        bool knownOffset;
        uint offset;
        
    public:
        this(string name, LabelDeclaration declaration, SourcePosition position)
        {
            super(DefinitionType.LABEL, name, position);
            this.declaration = declaration;
            this.knownOffset = false;
            this.offset = 0xFACEBEEF;
        }
    
        LabelDeclaration getDeclaration()
        {
            return declaration;
        }
        
        bool isKnownOffset()
        {
            return knownOffset;
        }
        
        uint getOffset()
        {
            return offset;
        }

        void setOffset(uint value)
        {
            knownOffset = true;
            offset = value;
        }
}

class ConstantDefinition : Definition
{
    private:
        ConstantDeclaration declaration;
    
    public:
        this(string name, ConstantDeclaration declaration, SourcePosition position)
        {
            super(DefinitionType.CONSTANT, name, position);
            this.declaration = declaration;
        }
    
        ConstantDeclaration getDeclaration()
        {
            return declaration;
        }
}

class VariableDefinition : Definition
{
    private:
        VariableDeclaration declaration;
        uint offset;
        
    public:
        this(string name, VariableDeclaration declaration, uint offset, SourcePosition position)
        {
            super(DefinitionType.VARIABLE, name, position);
            this.declaration = declaration;
            this.offset = offset;
        }
    
        VariableDeclaration getDeclaration()
        {
            return declaration;
        }
        
        uint getOffset()
        {
            return offset;
        }
}

class PackageDefinition : Definition
{
    private:
        SymbolTable table;
        
    public:
        this(string name, SymbolTable table, SourcePosition position)
        {
            super(DefinitionType.PACKAGE, name, position);
            this.table = table;
        }
        
        SymbolTable getTable()
        {
            return table;
        }
}