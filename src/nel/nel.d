module nel.nel;

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
public immutable string VERSION_TEXT = "0.1 (alpha build)";

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
            log("error: input '" ~ input ~ "' is a directory.");
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