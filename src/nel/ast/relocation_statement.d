module nel.ast.relocation_statement;

static import std.stdio;
static import std.string;

import nel.report;
import nel.ast.rom;
import nel.ast.node;
import nel.ast.statement;
import nel.ast.expression;

enum RelocationType
{
    RAM,
    ROM
}

class RelocationStatement : Statement
{
    private:
        RelocationType relocationType;
        Expression location;
        Expression bank;
        
    public:
        this(RelocationType relocationType, Expression location, SourcePosition position)
        {
            super(StatementType.RELOCATION, position);
            this.relocationType = relocationType;
            this.location = location;
        }
    
        this(Expression bank, Expression location, SourcePosition position)
        {
            this(RelocationType.ROM, location, position);
            this.bank = bank;
        }
        
        void aggregate()
        {
            if(relocationType == RelocationType.RAM && location !is null)
            {
                if(location.fold(true, false))
                {
                    romGenerator.moveRam(location.getFoldedValue());
                }
                else
                {
                    error("could not resolve the destination address provided to 'ram' relocation statement.", getPosition(), true);
                }
            }
        }
        
        void validate()
        {
            if(relocationType == RelocationType.ROM)
            {
                if(bank !is null)
                {
                    if(bank.fold(true, true))
                    {
                        romGenerator.switchBank(bank.getFoldedValue(), getPosition());
                    }
                    else
                    {
                        error("could not resolve the bank number provided to 'rom' relocation statement", getPosition(), true);
                    }
                }
                if(location !is null)
                {
                    if(location.fold(true, true))
                    {
                        RomBank activeBank = romGenerator.getActiveBank();
                        if(activeBank is null)
                        {
                            error("'rom' relocation found, but a rom bank hasn't been selected yet", getPosition(), true);
                        }
                        else
                        {
                            activeBank.org(location.getFoldedValue(), getPosition());
                        }
                    }
                    else
                    {
                        error("could not resolve the destination address provided to 'rom' relocation statement", getPosition(), true);
                    }
                }
            }
        }
        
        void generate()
        {
            if(relocationType == RelocationType.ROM)
            {
                if(bank)
                {
                    romGenerator.switchBank(bank.getFoldedValue(), getPosition());
                }
                
                RomBank activeBank = romGenerator.getActiveBank();
                if(activeBank is null)
                {
                    error("'rom' relocation found, but a rom bank hasn't been selected yet", getPosition(), true);
                }
                else
                {
                    activeBank.seekPosition(location.getFoldedValue(), getPosition());
                }
            }
        }
}