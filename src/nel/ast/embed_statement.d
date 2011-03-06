module nel.ast.embed_statement;

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

static import std.file;
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
            if(std.file.exists(filename))
            {
                if(std.file.isdir(filename))
                {
                    error("attempt to embed directory '" ~ filename ~ "'", getPosition(), true);
                    return;
                }
            }
            else
            {
                error("could not embed file '" ~ filename ~ "'", getPosition(), true);
                return;
            }
        
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