module nel.ast.label_declaration;

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