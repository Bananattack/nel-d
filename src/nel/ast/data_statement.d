module nel.ast.data_statement;

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

import nel.report;
import nel.ast.rom;
import nel.ast.node;
import nel.ast.statement;
import nel.ast.expression;
import nel.ast.storage_type;

enum DataType
{
    NUMERIC,
    STRING
}

class DataStatement : Statement
{
    private:
        StorageType storageType;
        DataItem[] items;
        
    public:
        this(StorageType storageType, DataItem[] items, SourcePosition position)
        {
            super(StatementType.DATA, position);
            this.storageType = storageType;
            this.items = items;
        }
        
        StorageType getStorageType()
        {
            return storageType;
        }
        
        DataItem[] getItems()
        {
            return items;
        }
        
        void aggregate()
        {
        }
        
        void validate()
        {
            uint baseSize = storageType == StorageType.WORD ? 2 : 1;
            uint size = 0;
            
            foreach(i, item; items)
            {   
                size += baseSize * item.calculateSize();
            }
            
            // Reserve the bytes needed for this data.
            RomBank bank = romGenerator.checkActiveBank("data statement", getPosition());
            if(bank !is null)
            {
                bank.expand(size, getPosition());
            }
        }
        
        void generate()
        {   
            RomBank bank = romGenerator.checkActiveBank("data statement", getPosition());
            if(bank !is null)
            {
                foreach(i, item; items)
                {   
                    item.write(bank, storageType);
                }
            }
        }
}

class DataItem : Node
{
    private:
        DataType dataType;
        
    public:
        this(DataType dataType, SourcePosition position)
        {
            super(position);
            this.dataType = dataType;
        }
        
        DataType getDataType()
        {
            return dataType;
        }
        
        abstract uint calculateSize();
        abstract void write(RomBank bank, StorageType storageType);
}

class NumericDataItem : DataItem
{
    private:
        Expression expression;
        
    public:
        this(Expression expression, SourcePosition position)
        {
            super(DataType.NUMERIC, position);
            this.expression = expression;
        }
        
        uint calculateSize()
        {
            expression.fold(false, true);
            return 1;
        }
        
        void write(RomBank bank, StorageType storageType)
        {
            if(!expression.fold(true, true))
            {
                return;
            }
            
            if(storageType == StorageType.WORD)
            {
                bank.writeWord(expression.getFoldedValue(), getPosition());
            }
            else
            {
                bank.writeByte(expression.getFoldedValue(), getPosition());
            }
        }
}

class StringDataItem : DataItem
{
    private:
        string value;
        
    public:
        this(string value, SourcePosition position)
        {
            super(DataType.STRING, position);
            this.value = value;
        }

        uint calculateSize()
        {
            return value.length;
        }
        
        void write(RomBank bank, StorageType storageType)
        {
            if(storageType == StorageType.WORD)
            {
                foreach(i, c; value)
                {
                    bank.writeWord(cast(uint) c, getPosition());
                }
            }
            else
            {
                foreach(i, c; value)
                {
                    bank.writeByte(cast(uint) c, getPosition());
                }
            }
        }
}