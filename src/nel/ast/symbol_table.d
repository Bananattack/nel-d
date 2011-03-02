module nel.ast.symbol_table;

static import std.stdio;

import nel.report;
import nel.ast.definition;

class SymbolTable
{
    private:
        SymbolTable parent;
        Definition[string] dictionary;
        
    public:
        this(SymbolTable parent = null)
        {
            this.parent = parent;
        }
        
        void printKeys()
        {
            foreach(key, value; dictionary)
            {
                std.stdio.writeln(key ~ ": " ~ value.toString());
            }
        }
        
        void put(Definition def)
        {
            // Perform search without inheritance to only whine if the symbol was already declared in this scope.
            // This way functions can have locals that use the same name as somewhere in the parent, without problems.
            // (get always looks at current scope and works up, there is no ambiguity)
            Definition match = tryGet(def.getName(), false);
        
            if(match)
            {
                error("redefinition of symbol '" ~ def.getName() ~ "' (previously defined at " ~ match.getPosition().toString() ~ ")", def.getPosition());
            }
            else
            {
                dictionary[def.getName()] = def;
            }
        }
        
        Definition tryGet(string name, bool useInheritance = true)
        {
            Definition* match = name in dictionary;
            if(match is null)
            {
                if(useInheritance && parent !is null)
                {
                    return parent.tryGet(name, useInheritance);
                }
                return null;
            }
            else
            {
                return *match;
            }
        }
}

private SymbolTable activeTable;
private SymbolTable[] tableStack;

SymbolTable getActiveTable()
{
    return activeTable;
}

void enterTable(SymbolTable table)
{
    tableStack ~= table;
    activeTable = table;
}

void exitTable()
{
    // Pop last element.
    tableStack.length = tableStack.length - 1;

    if(tableStack.length > 0)
    {
        activeTable = tableStack[tableStack.length - 1];
    }
    else
    {
        activeTable = null;
    }
}