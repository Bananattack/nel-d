module nel.nel;

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
static import std.path;
static import std.stdio;
static import std.string;

import nel.report;
import nel.ast.rom;
import nel.ast.block_statement;
import nel.parse.parser;
import nel.parse.scanner;

public immutable string PROGRAM_NAME = "nel";
public immutable string VERSION_TEXT = "0.1.2 (alpha build)";

private enum ArgumentState
{
    INPUT,
    OUTPUT
}

void handleErrors()
{
    if(getErrorCount() > 0)
    {
        fatalError();
    }
}

void main(string[] arguments)
{
    string[] args = arguments[1 .. arguments.length];
    
    ArgumentState state = ArgumentState.INPUT;
    string input;
    string output;
    
    notice("version " ~ VERSION_TEXT);
    
    foreach(i, arg; args)
    {
        if(arg[0] == '-')
        {
            switch(arg)
            {
                case "-o":
                    state = ArgumentState.OUTPUT;
                    break;
                case "-h":
                case "--help":
                    std.stdio.writeln("usage: " ~ PROGRAM_NAME ~ " [... arg]");
                    std.stdio.writeln("  where args can can be one of:");
                    std.stdio.writeln("    input_filename");
                    std.stdio.writeln("      (required) the name of the nel source file to compile");
                    std.stdio.writeln("    -o output_filename");
                    std.stdio.writeln("      the name of the .nes rom file to generate.");
                    std.stdio.writeln("      (defaults to $input_filename + '.nes').");
                    std.stdio.writeln("    -h, --help");
                    std.stdio.writeln("      this helpful mesage");
                    return;
                default:
                    notice(std.string.format("unknown command line option '%s'. ignoring...", arg));
                    break;
            }
        }
        else
        {
            switch(state)
            {
                case ArgumentState.INPUT:
                    
                    if(input != "")
                    {
                        notice(std.string.format("input file already set to '%s'. skipping '%s'", input, arg));
                    }
                    else
                    {
                        input = arg;
                    }
                    break;
                case ArgumentState.OUTPUT:
                    if(output != "")
                    {
                        notice(std.string.format("output file already set to '%s'. skipping '%s'", output, arg));
                    }
                    else
                    {
                        output = arg;
                    }
                    state = ArgumentState.INPUT;
                    break;
            }
        }
    }
    
    if(!input)
    {
        notice("no input file given. type `nel --help` to see program usage.");
        return;
    }
    // Assume a default file of <<input_filename>>.nes
    if(!output)
    {
        output = std.path.getName(input) ~ ".nes";
    }
    

    if(std.file.exists(input))
    {
        if(std.file.isdir(input))
        {
            log("error: input '" ~ input ~ "' is a directory.");
            return;
        }
    }
    else
    {
        log("error: input file '" ~ input ~ "' does not exist.");
        return;
    }
    
    if(std.file.exists(output) && std.file.isdir(output))
    {
        log("error: output '" ~ output ~ "' is a directory.");
        return;
    }

    Scanner scanner = new Scanner(std.stdio.File(input, "rb"), input);
    Parser parser = new Parser(scanner);
    BlockStatement block = parser.parse();
    if(block && getErrorCount() == 0)
    {   
        log("Aggregation...");
        block.aggregate();
        handleErrors();
        
        log("Validation...");
        block.validate();
        handleErrors();
        
        log("Generation...");
        romGenerator.resetRomPosition();
        block.generate();
        handleErrors();
        
        try
        {
            std.stdio.File file = std.stdio.File(output, "wb");
            log("Saving ROM...");
            romGenerator.dumpRaw(file);
            file.close();
        }
        catch(Exception e)
        {
            log("error: output '" ~ output ~ "' could not be written.");
            fatalError();
        }
        log("Wrote to '" ~ output ~ "'.");
        
        notice("Done.");
    }
    else
    {
        fatalError();
    }
}