module nel.ast.attribute;

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