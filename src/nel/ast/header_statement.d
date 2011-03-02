module nel.ast.header_statement;

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

class HeaderStatement : Statement
{
    private:
        static bool[string] recognizedSettings;
        static this()
        {
            recognizedSettings["mapper"] = true;
            recognizedSettings["prg"] = true;
            recognizedSettings["chr"] = true;
            recognizedSettings["mirroring"] = true;
            recognizedSettings["battery"] = true;
            recognizedSettings["fourscreen"] = true;
        }
        
        HeaderSegment[string] assigned;
        bool[string] accepted;
        HeaderSegment[] segments;
    public:
        this(HeaderSegment[] segments, SourcePosition position)
        {
            super(StatementType.HEADER, position);
            this.segments = segments;
        }
        
        HeaderSegment[] getSegments()
        {
            return segments;
        }
        
        void aggregate()
        {
            foreach(i, segment; segments)
            {   
                string name = segment.getName();
                if((name in assigned) is null)
                {
                    switch(name)
                    {
                        case "mapper":
                            accepted[name] = segment.checkValue(0, 255);
                            assigned[name] = segment;
                            break;
                        case "prg":
                            accepted[name] = segment.checkValue(1, 255); // Need at least on PRG.
                            assigned[name] = segment;
                            break;
                        case "chr":
                            accepted[name] = segment.checkValue(0, 255); // Can have 0 CHR if this uses CHR RAM.
                            assigned[name] = segment;
                            break;
                        case "mirroring":
                            accepted[name] = segment.checkValue(0, 1);
                            assigned[name] = segment;
                            break;
                        case "battery":
                            accepted[name] = segment.checkValue(0, 1);
                            assigned[name] = segment;
                            break;
                        case "fourscreen":
                            accepted[name] = segment.checkValue(0, 1);
                            assigned[name] = segment;
                            break;
                        default:
                            error("attempt to provide unrecognized setting '" ~ name ~ "'", segment.getPosition());
                            break;
                    }
                }
                else
                {
                    error("duplicate '" ~ name ~ "' setting found (previously set at " ~ assigned[name].getPosition().toString() ~ ")", segment.getPosition());
                }
            }
            
            // Check all settings. Uses bitwise AND to ensure that all settings are met.
            bool valid = checkSetting("mapper")
                & checkSetting("prg")
                & checkSetting("chr")
                & checkSetting("mirroring", false)
                & checkSetting("battery", false)
                & checkSetting("fourscreen", false);
                
            if(valid)
            {
                romGenerator = new RomGenerator(
                    assigned["mapper"].getExpression().getFoldedValue(),
                    assigned["prg"].getExpression().getFoldedValue(),
                    assigned["chr"].getExpression().getFoldedValue(),
                    ("mirroring" in assigned) is null ? false : assigned["mirroring"].getExpression().getFoldedValue() != 0,
                    ("battery" in assigned) is null ? false : assigned["battery"].getExpression().getFoldedValue() != 0,
                    ("fourscreen" in assigned) is null ? false : assigned["fourscreen"].getExpression().getFoldedValue() != 0
                );
            }
            else
            {
                error("ines header is invalid", getPosition(), true);
            }
        }
        
        bool checkSetting(string name, bool required = true)
        {
            // Missing setting?
            HeaderSegment* assign = name in assigned;
            bool* accept = name in accepted;
            if(assign is null)
            {
                if(required)
                {
                    error("header is missing required setting '" ~ name ~ "'", getPosition());
                    return false;
                }
                else
                {
                    return true;
                }
            }
            // Invalid setting?
            else
            {
                if(accept is null || !*accept)
                {
                    return false;
                }
                else
                {
                    return true;
                }
            }
        }
        
        void validate()
        {
        }
        
        void generate()
        {
        }
}

class HeaderSegment : Node
{
    private:
        string name;
        Expression expression;
        
    public:
        this(string name, Expression expression, SourcePosition position)
        {
            super(position);
            this.name = name;
            this.expression = expression;
        }
        
        string getName()
        {
            return name;
        }
        
        Expression getExpression()
        {
            return expression;
        }
        
        bool checkValue(uint min, uint max)
        {
            if(!expression.fold(true, false))
            {
                error(std.string.format("header has '%s' setting with a value which could not be resolved.", name), getPosition());
                return false;
            }
            else if(expression.getFoldedValue() < min || expression.getFoldedValue() > max)
            {
                error(std.string.format("header's '%s' setting must be between %s..%s, but got %s instead",
                    name, min, max, expression.getFoldedValue()), getPosition());
                return false;
            }
            return true;
        }
}