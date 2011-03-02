module nel.ast.statement;

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
    EMBED                   // A point to embed a binary file. 
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