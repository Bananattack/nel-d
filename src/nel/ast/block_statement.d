module nel.ast.block_statement;

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
import nel.ast.statement;
import nel.ast.definition;
import nel.ast.symbol_table;

enum BlockType
{
    MAIN,   // Implicit block around all code.
    SCOPE,  // Explicit begin/end (or package NAME/end block).
}

class BlockStatement : Statement
{
    private:
        BlockType blockType;
        string name;
        Statement[] statements;
        
        SymbolTable table;
    public:
        this(BlockType blockType, Statement[] statements, SourcePosition position)
        {
            super(StatementType.BLOCK, position);
            
            this.blockType = blockType;
            this.statements = statements;
        }
        
        this(BlockType blockType, string name, Statement[] statements, SourcePosition position)
        {
            this(blockType, statements, position);
            this.name = name;
        }
        
        BlockType getBlockType()
        {
            return blockType;
        }
        
        string getName()
        {
            return name;
        }
        
        Statement[] getStatements()
        {
            return statements;
        }
        
        bool handleHeader()
        {
            Statement header = null;
            foreach(i, statement; statements)
            {
                if(statement.getStatementType() == StatementType.HEADER)
                {
                    if(blockType == BlockType.MAIN)
                    {
                        if(header is null)
                        {
                            header = statement;
                        }
                        else
                        {
                            error("multiple ines headers found. (first header at "
                                ~ header.getPosition().toString ~ ").", statement.getPosition());
                        }
                    }
                    else
                    {
                        error("ines header cannot appear inside a block.", getPosition());
                    }
                }
                else if(blockType == BlockType.MAIN && !header)
                {
                    if(statement.getStatementType() != StatementType.CONSTANT && statement.getStatementType() != StatementType.ENUM)
                    {
                        error("statement that is not a constant declaration found before the ines header.",
                            statement.getPosition(), true);
                        return false;
                    }
                }
            }
            
            if(blockType == BlockType.MAIN)
            {
                if(!header)
                {
                    error("no ines header found.", getPosition(), true);
                    return false;
                }
                
                header.aggregate();
                
                // Header errors are fatal, so if we actually make it here, we can return true.
                return true;
            }
            return false;
        }
        
        void aggregate()
        {
            SymbolTable activeTable = getActiveTable();
            
            // Package?
            if(name.length > 0 && activeTable !is null)
            {
                // If there was already a package defined by that name declared
                // in this scope (and not a parent), then reuse that table.
                PackageDefinition pkg = cast(PackageDefinition) activeTable.tryGet(name, false);
                
                // Reuse existing table.
                if(pkg !is null)
                {
                    table = pkg.getTable();
                }
                // No previous table existed. Update scope.
                // Add this table to the parent scope.
                else
                {
                    table = new SymbolTable(activeTable);
                    activeTable.put(new PackageDefinition(name, table, getPosition()));
                }
            }
            else
            {
                table = new SymbolTable(activeTable);
            }
            
            enterTable(table);
            
            // Gather all constant definitions.
            foreach(i, statement; statements)
            {
                if(statement.getStatementType() == StatementType.CONSTANT
                    || statement.getStatementType() == StatementType.ENUM)
                {
                    statement.aggregate();
                }
            }
            
            // Handle header/whatever, and then parse all other things in a block.
            if(handleHeader() || blockType != BlockType.MAIN)
            {
                foreach(i, statement; statements)
                {
                    if(statement.getStatementType() != StatementType.CONSTANT
                        && statement.getStatementType() != StatementType.ENUM
                        && statement.getStatementType() != StatementType.HEADER)
                    {
                        statement.aggregate();
                    }
                }
            }
            exitTable();
        }
        
        void validate()
        {
            enterTable(table);
            // Check out all the statements that this contains.
            foreach(i, statement; statements)
            {
                statement.validate();
            }
            exitTable();
        }
        
        void generate()
        {
            enterTable(table);
            // Check out all the statements that this contains.
            foreach(i, statement; statements)
            {
                statement.generate();
            }
            exitTable();
        }
}
