module nel.report;

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
