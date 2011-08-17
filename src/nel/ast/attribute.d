module nel.ast.attribute;

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
import nel.ast.node;
import nel.ast.definition;
import nel.ast.symbol_table;

class Attribute : Node
{
    private:
        string[] pieces;
        
    public:
        this(string[] pieces, SourcePosition position)
        {
            super(position);
            
            this.pieces = pieces;
        }
        
        string getFullName()
        {
            return std.string.join(pieces, ".");
        }
        
        Definition resolve()
        {
            Definition prev, def;
            SymbolTable table = getActiveTable();
            string[] partialQualifiers;
            
            foreach(i, piece; pieces)
            {
                partialQualifiers ~= piece;
                
                if(prev is null)
                {
                    def = table.tryGet(piece, true);
                }
                else
                {
                    PackageDefinition pkg = cast(PackageDefinition) prev;
                    if(pkg is null)
                    {
                        string fullyQualifiedName = std.string.join(pieces, ".");
                        string previousName = std.string.join(partialQualifiers[0 .. partialQualifiers.length - 1], ".");
                        error("attempt to get symbol '" ~ fullyQualifiedName ~ "', but '" ~ previousName ~ "' is not a package", getPosition());
                    }
                    else
                    {
                        table = pkg.getTable();
                        def = table.tryGet(piece, false);
                    }
                }
                
                if(def is null)
                {
                    string partiallyQualifiedName = std.string.join(partialQualifiers, ".");
                    string fullyQualifiedName = std.string.join(pieces, ".");
                    
                    if(partiallyQualifiedName == fullyQualifiedName)
                    {
                        error("reference to undefined symbol '" ~ partiallyQualifiedName ~ "'", getPosition());
                    }
                    else
                    {
                        error("reference to undefined symbol '" ~ partiallyQualifiedName ~ "' (in '" ~ fullyQualifiedName ~ "')", getPosition());
                    }
                    return null;
                }
                
                prev = def;
            }
            return def;
        }
}