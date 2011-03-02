module nel.ast.embed_statement;

static import std.stdio;

import nel.report;
import nel.ast.rom;
import nel.ast.node;
import nel.ast.statement;

class EmbedStatement : Statement
{
    private:
        string filename;
        uint size;
    
    public:
        this(string filename, SourcePosition position)
        {
            super(StatementType.EMBED, position);
            this.filename = filename;
            this.size = 0;
        }
        
        string getFilename()
        {
            return filename;
        }
        
        void aggregate()
        {
        }
        
        void validate()
        {   
            try
            {
                std.stdio.File file = std.stdio.File(filename, "rb");
                file.seek(0, std.stdio.SEEK_SET);
                ulong start = file.tell();
                file.seek(0, std.stdio.SEEK_END);
                ulong end = file.tell();
                file.close();
                
                size = cast(uint) (end - start);
            }
            catch(std.stdio.Exception e)
            {
                error("could not embed file '" ~ filename ~ "' (" ~ e.toString ~ ")", getPosition(), true);
                return;
            }
            
            // Reserve the bytes needed for this data.
            // (Previous errors shouldn't wreck the size calculation).
            RomBank bank = romGenerator.checkActiveBank("embed statement", getPosition());
            if(bank !is null)
            {
                bank.expand(size, getPosition());
            }
        }
        
        void generate()
        {
            ubyte[] data = new ubyte[size];
            
            try
            {
                std.stdio.File file = std.stdio.File(filename, "rb");
                file = std.stdio.File(filename, "rb");
                file.rawRead(data);
                file.close();
            }
            catch(std.stdio.Exception e)
            {
                error("could not embed file '" ~ filename ~ "' (" ~ e.toString ~ ")", getPosition(), true);
                return;
            }
            
            RomBank bank = romGenerator.checkActiveBank("embed statement", getPosition());
            if(bank !is null)
            {
                for(uint i = 0; i < size; i++)
                {
                    bank.writeByte(data[i], getPosition());
                }
            }
        }
}