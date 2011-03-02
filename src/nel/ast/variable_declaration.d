module nel.ast.variable_declaration;

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