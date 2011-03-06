module nel.report;

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

static import std.stdio;
static import std.string;
static import std.conv;
static import std.c.stdlib;

import nel.nel;

class SourceFile
{
    private:
        string filename;
        SourcePosition includePoint;
        
    public:
        this(string filename, SourcePosition includePoint = null)
        {
            this.filename = filename;
            this.includePoint = includePoint;
        }
    
        string getFilename()
        {
            return filename;
        }
    
        string toString(bool verbose = false)
        {
            return filename ~ (verbose && includePoint !is null ? " (included at " ~ includePoint.toString() ~ ")" : "");
        }
}

class SourcePosition
{
    private:
        SourceFile file;
        uint line;
        
    public:
        this(SourceFile file)
        {
            this.file = file;
        }
        
        this(SourcePosition position)
        {
            this.file = position.file;
            this.line = position.line;
        }
        
        uint getLine()
        {
            return line;
        }
        
        SourceFile getFile()
        {
            return file;
        }
        
        string toString()
        {
            return file.toString() ~ ":" ~ std.conv.to!string(line);
        }
        
        void incrementLine()
        {
            line++;
        }
}

private int errorCount;

void error(string message, SourcePosition position, bool fatal = false)
{
    log(std.conv.to!string(position) ~ ": " ~ (fatal ? "fatal" : "error") ~ ": " ~ message);
    errorCount++;
    if(fatal)
    {
        fatalError();
    }
}

uint getErrorCount()
{
    return errorCount;
}

void notice(string message)
{
    std.stdio.writefln("* %s: %s", PROGRAM_NAME, message);
}

void log(string message)
{
    std.stdio.writeln("  " ~ message);
}

void fatalError()
{
    notice(std.string.format("failed with %d error(s).", errorCount));
    std.c.stdlib.exit(1);
}
