module nel.ast.constant_declaration;

import nel.report;
import nel.ast.statement;
import nel.ast.definition;
import nel.ast.expression;
import nel.ast.symbol_table;

class ConstantDeclaration : Statement
{
    private:
        string name;
        Expression expression;
        
    public:
        this(string name, Expression expression, SourcePosition position)
        {
            super(StatementType.CONSTANT, position);
            this.name = name;
            this.expression = expression;
        }
        
        Expression getExpression()
        {
            return expression;
        }
        
        void aggregate()
        {
            getActiveTable().put(new ConstantDefinition(name, this, getPosition()));
        }
        
        void validate()
        {
        }
        
        void generate()
        {
        }
}