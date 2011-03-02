module nel.ast.command_statement;

import nel.report;
import nel.ast.rom;
import nel.ast.node;
import nel.ast.builtin;
import nel.ast.argument;
import nel.ast.statement;

enum CommandType
{
    INSTRUCTION,    // A command that has a machine instruction
    MACRO           // A user-defined command macro (TODO)
}

class CommandStatement : Statement
{
    private:
        Command[] commands;
 
    public:
        this(Command[] commands, SourcePosition position)
        {
            super(StatementType.COMMAND, position);
            this.commands = commands;
        }
        
        Command[] getCommands()
        {
            return commands;
        }
        
        void aggregate()
        {
        }
        
        void validate()
        {
            // Reserve the bytes needed for this data.
            RomBank bank = romGenerator.checkActiveBank("command statement", getPosition());
            if(bank is null)
            {
                return;
            }
            
            foreach(i, command; commands)
            {
                if(command !is null)
                {
                    bank.expand(command.calculateSize(), command.getPosition());
                }
            }
        }
        
        void generate()
        {
            // Reserve the bytes needed for this data.
            RomBank bank = romGenerator.checkActiveBank("command statement", getPosition());
            if(bank is null)
            {
                return;
            }
            
            foreach(i, command; commands)
            {
                if(command !is null)
                {
                    command.write(bank);
                }
            }
        }
}

abstract class Command : Node
{
    protected:
        CommandType commandType;
        Argument receiver;
        Argument[] arguments;
        
    public:
        this(CommandType commandType, Argument receiver, Argument[] arguments, SourcePosition position)
        {
            super(position);
            
            this.commandType = commandType;
            this.receiver = receiver;
            this.arguments = arguments;
        }
        
        CommandType getCommandType()
        {
            return commandType;
        }
        
        Argument getReceiver()
        {
            return receiver;
        }
        
        Argument[] getArguments()
        {
            return arguments;
        }
        
        abstract uint calculateSize();
        abstract void write(RomBank bank);
}

class InstructionCommand : Command
{
    private:
        BuiltinInstruction instruction;
        BuiltinInstruction oldInstruction;
        uint size;
        
    public:
        this(BuiltinInstruction instruction, Argument receiver, Argument[] arguments, SourcePosition position)
        {
            super(CommandType.INSTRUCTION, receiver, arguments, position);
            this.instruction = instruction;
            this.oldInstruction = BuiltinInstruction.NONE;
            this.size = 0;
        }
        
        BuiltinInstruction getInstruction()
        {
            return instruction;
        }
        
        private void commandError(string msg)
        {
            string err = "invalid '" ~ getBuiltinInstructionName(instruction) ~ "' command";
            if(oldInstruction != BuiltinInstruction.NONE)
            {
                err ~= " (converted from 'M: " ~ getBuiltinInstructionName(oldInstruction) ~ " argument')";
            }
            err ~= ": " ~ msg;
            error(err, getPosition());
        }

        private void badReceiverError(string msg)
        {
            string err = "receiver cannot be " ~ getArgumentDescription(receiver.getArgumentType()) ~ ". " ~ msg;
            commandError(err);
        }
        
        private void badArgumentError(string msg)
        {
            string err = "argument cannot be " ~ getArgumentDescription(arguments[0].getArgumentType()) ~ ". " ~ msg;
            commandError(err);
        }

        private void useImplicitSize()
        {
            size = 1;
        }

        private void useZeroPageSize(Argument arg)
        {
            arg.forceZeroPage();
            size = 2;
        }
        
        private void useZeroPageOrAbsoluteSize(Argument arg)
        {
            arg.checkForZeroPage();
            size = arg.isZeroPage() ? 2 : 3;
        }
        
        private void useAbsoluteSize()
        {
            size = 3;
        }
        
        private void flipInstruction()
        {
            // Swap receiver and argument, and make this a put.
            Argument temp = receiver;
            receiver = arguments[0];
            arguments[0] = temp;
            
            // Change GET into PUT, PUT into GET.
            oldInstruction = instruction;
            if(instruction == BuiltinInstruction.GET)
            {
                instruction = BuiltinInstruction.PUT;
            }
            else if(instruction == BuiltinInstruction.PUT)
            {
                instruction = BuiltinInstruction.GET;
            }
        }
        
        private bool checkArgumentCount(uint expected)
        {
            if(arguments.length != expected)
            {
                commandError(
                    std.string.format(
                        "too " ~ (arguments.length < expected ? "few" : "many") ~ " arguments."
                        ~ " (got %s, but expected %s)",
                        arguments.length, expected
                    )
                );
                return false;
            }
            else
            {
                return true;
            }
        }
        
        uint calculateSize()
        {
            if(size > 0)
            {
                return size;
            }
            
            // Not possible by any command, and this prevents an infinite recursion
            // in some statements like get which convert 'M: get src' into 'src: put M'.
            if(receiver !is null && receiver.isMemoryTerm()
                && arguments.length > 0 && arguments[0] !is null && arguments[0].isMemoryTerm())
            {
                commandError("receiver and argument cannot both be memory terms.");
                return 0;
            }
            
            switch(instruction)
            {
                case BuiltinInstruction.GET:
                    if(!checkArgumentCount(1)) return 0;
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.X:
                                case ArgumentType.Y:
                                    useImplicitSize();
                                    break;
                                case ArgumentType.IMMEDIATE:
                                case ArgumentType.INDEXED_BY_X_INDIRECT:
                                case ArgumentType.INDIRECT_INDEXED_BY_Y:
                                    useZeroPageSize(arguments[0]);
                                    break;
                                case ArgumentType.DIRECT:
                                case ArgumentType.INDEXED_BY_X:
                                    useZeroPageOrAbsoluteSize(arguments[0]);
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    useAbsoluteSize();
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'a', then the argument must be the register 'x' or 'y', an immediate value #expr, a direct memory term of form @expr, @expr[x] or @expr[y], or an indirect term of form @[expr[x]] or @[expr][y]");
                                    break;
                            }
                            break;
                        case ArgumentType.X:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.A:
                                case ArgumentType.S:
                                    useImplicitSize();
                                    break;
                                case ArgumentType.IMMEDIATE:
                                    useZeroPageSize(arguments[0]);
                                    break;
                                case ArgumentType.DIRECT:
                                case ArgumentType.INDEXED_BY_Y:
                                    useZeroPageOrAbsoluteSize(arguments[0]);
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'x', then the argument must be the register 'a' or 's', an immediate value #expr, or a direct memory term of form @expr or @expr[y]");
                                    break;
                            }
                            break;
                        case ArgumentType.Y:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.A:
                                    useImplicitSize();
                                    break;
                                case ArgumentType.IMMEDIATE:
                                    useZeroPageSize(arguments[0]);
                                    break;
                                case ArgumentType.DIRECT:
                                case ArgumentType.INDEXED_BY_X:
                                    useZeroPageOrAbsoluteSize(arguments[0]);
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'y', then the argument must be the register 'a', an immediate value #expr, or a direct memory term of form @expr or @expr[x]");
                                    break;
                            }
                            break;
                        case ArgumentType.S:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.X:
                                    useImplicitSize();
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'x', then the argument must be 'x'");
                                    break;
                            }
                            break;
                        case ArgumentType.DIRECT:
                        case ArgumentType.INDEXED_BY_X:
                        case ArgumentType.INDEXED_BY_Y:
                        case ArgumentType.INDEXED_BY_X_INDIRECT:
                        case ArgumentType.INDIRECT_INDEXED_BY_Y:
                            flipInstruction();
                            return calculateSize();
                        default:
                            badReceiverError("must be the register 'a', 'x', 'y', or 's', or some memory term that is not an immediate value");
                            break;
                    }
                    break;
                case BuiltinInstruction.PUT:
                    if(!checkArgumentCount(1)) return 0;
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.X:
                                case ArgumentType.Y:
                                    useImplicitSize();
                                    break;
                                case ArgumentType.INDEXED_BY_X_INDIRECT:
                                case ArgumentType.INDIRECT_INDEXED_BY_Y:
                                    useZeroPageSize(arguments[0]);
                                    break;
                                case ArgumentType.DIRECT:
                                case ArgumentType.INDEXED_BY_X:
                                    useZeroPageOrAbsoluteSize(arguments[0]);
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    useAbsoluteSize();
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'a', then the argument must be the register 'x' or 'y', a direct memory term of form @expr, @expr[x] or @expr[y], or an indirect term of form @[expr[x]] or @[expr][y]");
                                    break;
                            }
                            break;
                        case ArgumentType.X:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.A:
                                case ArgumentType.S:
                                    useImplicitSize();
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    // Assume zero-page since there is no absolute direct-index mode for stx.
                                    useZeroPageSize(arguments[0]);
                                    break;
                                case ArgumentType.DIRECT:
                                    useZeroPageOrAbsoluteSize(arguments[0]);
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'x', then the argument must be the register 'a' or 's', or a direct memory term of form @expr or @expr[y]");
                                    break;
                            }
                            break;
                        case ArgumentType.Y:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.A:
                                    useImplicitSize();
                                    break;
                                case ArgumentType.INDEXED_BY_X:
                                    // Assume zero-page since there is no absolute direct-index mode for sty.
                                    useZeroPageSize(arguments[0]);
                                    break;
                                case ArgumentType.DIRECT:
                                    useZeroPageOrAbsoluteSize(arguments[0]);
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'y', then the argument must be the register 'a', or a direct memory term of form @expr or @expr[x]");
                                    break;
                            }
                            break;
                        case ArgumentType.S:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.X:
                                    useImplicitSize();
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'x', then the argument must be 'x'");
                                    break;
                            }
                            break;
                        case ArgumentType.IMMEDIATE:
                        case ArgumentType.DIRECT:
                        case ArgumentType.INDEXED_BY_X:
                        case ArgumentType.INDEXED_BY_Y:
                        case ArgumentType.INDEXED_BY_X_INDIRECT:
                        case ArgumentType.INDIRECT_INDEXED_BY_Y:
                        {
                            flipInstruction();
                            return calculateSize();
                        }
                        default:
                            badReceiverError("receiver must be the register 'a', 'x', 'y', or 's', or some memory term");
                            break;
                    }
                    break;
                // This has A, X or Y as a receiver. No argument.
                case BuiltinInstruction.CMP:
                    if(!checkArgumentCount(1)) return 0;
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.IMMEDIATE:
                                case ArgumentType.INDEXED_BY_X_INDIRECT:
                                case ArgumentType.INDIRECT_INDEXED_BY_Y:
                                    useZeroPageSize(arguments[0]);
                                    break;
                                case ArgumentType.DIRECT:
                                case ArgumentType.INDEXED_BY_X:
                                    useZeroPageOrAbsoluteSize(arguments[0]);
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    useAbsoluteSize();
                                    break;
                                default:
                                    badArgumentError("if receiver is the register 'a', then the argument must be an immediate value #expr, a direct memory term of form @expr, @expr[x] or @expr[y], or an indirect term of form @[expr[x]] or @[expr][y]");
                                    break;
                            }
                            break;
                        case ArgumentType.X:
                        case ArgumentType.Y:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.IMMEDIATE:
                                    useZeroPageSize(arguments[0]);
                                    break;
                                case ArgumentType.DIRECT:
                                    useZeroPageOrAbsoluteSize(arguments[0]);
                                    break;
                                default:
                                    badArgumentError("if receiver is an index register, then the argument must be an immediate value #expr, or a direct memory term of form @expr");
                                    break;
                            }
                            break;
                        default:
                            badReceiverError("must be the register 'a', 'x', or 'y'.");
                            break;
                    }
                    break;
                // This uses A as a receiver. One argument.
                case BuiltinInstruction.ADD:
                case BuiltinInstruction.ADDC:
                case BuiltinInstruction.SUB:
                case BuiltinInstruction.SUBC:
                case BuiltinInstruction.OR:
                case BuiltinInstruction.AND:
                case BuiltinInstruction.XOR:
                    if(!checkArgumentCount(1)) return 0;
                    if(receiver.getArgumentType() == ArgumentType.A)
                    {
                        switch(arguments[0].getArgumentType())
                        {
                            case ArgumentType.IMMEDIATE:
                            case ArgumentType.INDEXED_BY_X_INDIRECT:
                            case ArgumentType.INDIRECT_INDEXED_BY_Y:
                                useZeroPageSize(arguments[0]);
                                break;
                            case ArgumentType.DIRECT:
                            case ArgumentType.INDEXED_BY_X:
                                useZeroPageOrAbsoluteSize(arguments[0]);
                                break;
                            case ArgumentType.INDEXED_BY_Y:
                                useAbsoluteSize();
                                break;
                            default:
                                badArgumentError("must be an immediate value #expr, a direct memory term of form @expr, @expr[x] or @expr[y], or an indirect term of form @[expr[x]] or @[expr][y]");
                                break;
                        }
                        if(instruction == BuiltinInstruction.ADD || instruction == BuiltinInstruction.SUB)
                        {
                            // add size of clc / sec {+1}
                            size += 1;
                        }
                    }
                    else
                    {
                        badReceiverError("must be the register 'a'.");
                    }
                    break;
                // This uses A as a receiver. One argument.
                case BuiltinInstruction.BIT:
                    if(!checkArgumentCount(1)) return 0;
                    if(receiver.getArgumentType() == ArgumentType.A)
                    {
                        switch(arguments[0].getArgumentType())
                        {
                            case ArgumentType.DIRECT:
                                useZeroPageOrAbsoluteSize(arguments[0]);
                                break;
                            default:
                                badArgumentError("must be a direct memory term of form @expr");
                                break;
                        }
                    }
                    else
                    {
                        badReceiverError("must be the register 'a'.");
                    }
                    break;
                // This has X, Y or a memory term as a receiver. No argument.
                case BuiltinInstruction.INC:
                case BuiltinInstruction.DEC:
                    if(!checkArgumentCount(0)) return 0;
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.X:
                        case ArgumentType.Y:
                            useImplicitSize();
                            break;
                        case ArgumentType.DIRECT:
                        case ArgumentType.INDEXED_BY_X:
                            useZeroPageOrAbsoluteSize(receiver);
                            break;
                        default:
                            badReceiverError("must be the register 'x', register 'y', or a direct memory term of form @expr, or @expr[x].");
                            break;
                    }
                    break;
                // This has A as a receiver. No argument.
                case BuiltinInstruction.NOT:
                    if(!checkArgumentCount(0)) return 0;
                    if(receiver.getArgumentType() == ArgumentType.A)
                    {
                        // size of eor #0xff {+2}
                        size = 2;
                    }
                    else
                    {
                        badReceiverError("must be the register 'a'.");
                    }
                    break;
                // This has A as a receiver. No argument.
                case BuiltinInstruction.NEG:
                    if(!checkArgumentCount(0)) return 0;
                    if(receiver.getArgumentType() == ArgumentType.A)
                    {
                        // size of clc {+1}, eor #0xff {+2}, adc #1 {+2}
                        size = 5;
                    }
                    else
                    {
                        badReceiverError("must be the register 'a'.");
                    }
                    break;
                // These have A or a memory term as a receiver. No argument.
                case BuiltinInstruction.SHL:
                case BuiltinInstruction.SHR:
                case BuiltinInstruction.ROL:
                case BuiltinInstruction.ROR:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            useImplicitSize();
                            break;
                        case ArgumentType.DIRECT:
                        case ArgumentType.INDEXED_BY_X:
                            useZeroPageOrAbsoluteSize(receiver);
                            break;
                        default:
                            badReceiverError("must be the register 'a', or a direct memory term of form @expr, or @expr[x].");
                            break;
                    }
                    break;
                // These have A or P as a receiver.
                case BuiltinInstruction.PUSH:
                case BuiltinInstruction.PULL:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                        case ArgumentType.P:
                            useImplicitSize();
                            break;
                        default:
                            badReceiverError("must be the register 'a' or 'p'.");
                            break;
                    }
                    break;
                // These require a p-flag argument (error if there is none)
                case BuiltinInstruction.SET:
                    if(receiver.getArgumentType() == ArgumentType.P)
                    {
                        switch(arguments[0].getArgumentType())
                        {
                            case ArgumentType.CARRY:
                            case ArgumentType.INTERRUPT:
                            case ArgumentType.DECIMAL:
                                useImplicitSize();
                                break;
                            default:
                                badArgumentError("must be the p-flag 'carry', 'interrupt', or 'decimal'.");
                                break;
                        }
                    }
                    else
                    {
                        badReceiverError("must be the register 'p'.");
                    }
                    break;
                case BuiltinInstruction.UNSET:
                    if(receiver.getArgumentType() == ArgumentType.P)
                    {
                        switch(arguments[0].getArgumentType())
                        {
                            case ArgumentType.CARRY:
                            case ArgumentType.INTERRUPT:
                            case ArgumentType.DECIMAL:
                            case ArgumentType.OVERFLOW:
                                useImplicitSize();
                                break;
                            default:
                                badArgumentError("must be the p-flag 'carry', 'interrupt', 'decimal', or 'overflow'.");
                                break;
                        }
                    }
                    else
                    {
                        badReceiverError("must be the register 'p'.");
                    }
                    break;
            }
            return size;
        }
        
        void write(RomBank bank)
        {
            bool defaultAssembly = true;
            uint opcode = 0;
            switch(instruction)
            {
                case BuiltinInstruction.GET:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.X:
                                    opcode = 0x8A; // txa
                                    break;
                                case ArgumentType.Y:
                                    opcode = 0x98; // tya
                                    break;
                                case ArgumentType.IMMEDIATE:
                                    opcode = 0xA9; // lda #imm
                                    break;
                                case ArgumentType.INDEXED_BY_X_INDIRECT:
                                    opcode = 0xA1; // lda [mem, x]
                                    break;
                                case ArgumentType.INDIRECT_INDEXED_BY_Y:
                                    opcode = 0xB1; // lda [mem], y
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0xA5 : 0xAD; // lda mem
                                    break;
                                case ArgumentType.INDEXED_BY_X:
                                    opcode = arguments[0].isZeroPage() ? 0xB5 : 0xBD; // lda mem, x
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    opcode = 0xB9; // lda mem, y
                                    break;
                            }
                            break;
                        case ArgumentType.X:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.A:
                                    opcode = 0xAA; // tax
                                    break;
                                case ArgumentType.S:
                                    opcode = 0xBA; // tsx
                                    break;
                                case ArgumentType.IMMEDIATE:
                                    opcode = 0xA2; // ldx #imm
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0xA6 : 0xAE; // ldx mem
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    opcode = arguments[0].isZeroPage() ? 0xB4 : 0xBE; // ldx mem, y
                                    break;
                            }
                            break;
                        case ArgumentType.Y:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.A:
                                    opcode = 0xA8; // tay
                                    break;
                                case ArgumentType.IMMEDIATE:
                                    opcode = 0xA0; // ldy #imm
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0xA4 : 0xAC; // ldy mem
                                    break;
                                case ArgumentType.INDEXED_BY_X:
                                    opcode = arguments[0].isZeroPage() ? 0xB4 : 0xBC; // ldy mem, x
                                    break;
                            }
                            break;
                        case ArgumentType.S:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.X:
                                    opcode = 0x9A; // txs
                                    break;
                            }
                            break;
                    }
                    break;
                case BuiltinInstruction.PUT:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.X:
                                    opcode = 0xAA; // tax
                                    break;
                                case ArgumentType.Y:
                                    opcode = 0xA8; // tay
                                    break;
                                case ArgumentType.INDEXED_BY_X_INDIRECT:
                                    opcode = 0x81; // sta [mem, x]
                                    break;
                                case ArgumentType.INDIRECT_INDEXED_BY_Y:
                                    opcode = 0x91; // sta [mem], y
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0x85: 0x8D; // sta mem
                                    break;
                                case ArgumentType.INDEXED_BY_X:
                                    opcode = arguments[0].isZeroPage() ? 0x95: 0x9D; // sta mem, x
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    opcode = 0x99; // sta mem, y
                                    break;
                            }
                            break;
                        case ArgumentType.X:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.A:
                                    opcode = 0x8A; // txa
                                    break;
                                case ArgumentType.S:
                                    opcode = 0x9A; // txs
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    opcode = 0x96; // stx zp, y
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0x86 : 0x8E; // stx mem
                                    break;
                            }
                            break;
                        case ArgumentType.Y:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.A:
                                    opcode = 0x98; // tya
                                    break;
                                case ArgumentType.INDEXED_BY_X:
                                    opcode = 0x94; // sty zp, x
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0x84 : 0x8C; // sty mem
                                    break;
                            }
                            break;
                        case ArgumentType.S:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.X:
                                    opcode = 0xBA; // tsx
                                    break;
                            }
                            break;
                    }
                    break;
                case BuiltinInstruction.CMP:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.IMMEDIATE:
                                    opcode = 0xC9; // cmp #imm
                                    break;
                                case ArgumentType.INDEXED_BY_X_INDIRECT:
                                    opcode = 0xC1; // cmp [mem, x]
                                    break;
                                case ArgumentType.INDIRECT_INDEXED_BY_Y:
                                    opcode = 0xD1; // cmp [mem], y
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0xC5 : 0xCD; // cmp mem
                                    break;
                                case ArgumentType.INDEXED_BY_X:
                                    opcode = arguments[0].isZeroPage() ? 0xD5 : 0xDD; // cmp mem, x
                                    break;
                                case ArgumentType.INDEXED_BY_Y:
                                    opcode = 0xD1; // cmp mem, y
                                    break;
                            }
                            break;
                        case ArgumentType.X:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.IMMEDIATE:
                                    opcode = 0xE0; // cpx #imm
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0xE4 : 0xEC; // cpx mem
                                    break;
                            }
                            break;
                        case ArgumentType.Y:
                            switch(arguments[0].getArgumentType())
                            {
                                case ArgumentType.IMMEDIATE:
                                    opcode = 0xC0; // cpy #imm
                                    break;
                                case ArgumentType.DIRECT:
                                    opcode = arguments[0].isZeroPage() ? 0xC4 : 0xCC; // cpy mem
                                    break;
                            }
                            break;
                    }
                    break;
                case BuiltinInstruction.ADD:
                    bank.writeByte(0x18, getPosition()); // clc
                    // fallthrough for adc
                case BuiltinInstruction.ADDC:
                    switch(arguments[0].getArgumentType())
                    {
                        case ArgumentType.IMMEDIATE:
                            opcode = 0x69; // adc #imm
                            break;
                        case ArgumentType.INDEXED_BY_X_INDIRECT:
                            opcode = 0x61; // adc [mem, x]
                            break;
                        case ArgumentType.INDIRECT_INDEXED_BY_Y:
                            opcode = 0x71; // adc [mem], y
                            break;
                        case ArgumentType.DIRECT:
                            opcode = arguments[0].isZeroPage() ? 0x65 : 0x6D; // adc mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = arguments[0].isZeroPage() ? 0x75 : 0x7D; // adc mem, x
                            break;
                        case ArgumentType.INDEXED_BY_Y:
                            opcode = 0x79; // adc mem, y
                            break;
                    }
                    break;
                case BuiltinInstruction.SUB:
                    bank.writeByte(0x38, getPosition()); // secc
                    // fallthrough for sbc
                case BuiltinInstruction.SUBC:
                    switch(arguments[0].getArgumentType())
                    {
                        case ArgumentType.IMMEDIATE:
                            opcode = 0xE9; // sbc #imm
                            break;
                        case ArgumentType.INDEXED_BY_X_INDIRECT:
                            opcode = 0xE1; // sbc [mem, x]
                            break;
                        case ArgumentType.INDIRECT_INDEXED_BY_Y:
                            opcode = 0xF1; // sbc [mem], y
                            break;
                        case ArgumentType.DIRECT:
                            opcode = arguments[0].isZeroPage() ? 0xE5 : 0xED; // sbc mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = arguments[0].isZeroPage() ? 0xF5 : 0xFD; // sbc mem, x
                            break;
                        case ArgumentType.INDEXED_BY_Y:
                            opcode = 0xF9; // sbc mem, y
                            break;
                    }
                    break;
                case BuiltinInstruction.OR:
                    switch(arguments[0].getArgumentType())
                    {
                        case ArgumentType.IMMEDIATE:
                            opcode = 0x09; // ora #imm
                            break;
                        case ArgumentType.INDEXED_BY_X_INDIRECT:
                            opcode = 0x01; // ora [mem, x]
                            break;
                        case ArgumentType.INDIRECT_INDEXED_BY_Y:
                            opcode = 0x11; // ora [mem], y
                            break;
                        case ArgumentType.DIRECT:
                            opcode = arguments[0].isZeroPage() ? 0x05 : 0x0D; // ora mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = arguments[0].isZeroPage() ? 0x15 : 0x1D; // ora mem, x
                            break;
                        case ArgumentType.INDEXED_BY_Y:
                            opcode = 0x19; // ora mem, y
                            break;
                    }
                    break;
                case BuiltinInstruction.AND:
                    switch(arguments[0].getArgumentType())
                    {
                        case ArgumentType.IMMEDIATE:
                            opcode = 0x29; // and #imm
                            break;
                        case ArgumentType.INDEXED_BY_X_INDIRECT:
                            opcode = 0x21; // and [mem, x]
                            break;
                        case ArgumentType.INDIRECT_INDEXED_BY_Y:
                            opcode = 0x31; // and [mem], y
                            break;
                        case ArgumentType.DIRECT:
                            opcode = arguments[0].isZeroPage() ? 0x25 : 0x2D; // and mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = arguments[0].isZeroPage() ? 0x35 : 0x3D; // and mem, x
                            break;
                        case ArgumentType.INDEXED_BY_Y:
                            opcode = 0x39; // and mem, y
                            break;
                    }
                    break;
                case BuiltinInstruction.XOR:
                    switch(arguments[0].getArgumentType())
                    {
                        case ArgumentType.IMMEDIATE:
                            opcode = 0x49; // eor #imm
                            break;
                        case ArgumentType.INDEXED_BY_X_INDIRECT:
                            opcode = 0x41; // eor [mem, x]
                            break;
                        case ArgumentType.INDIRECT_INDEXED_BY_Y:
                            opcode = 0x51; // eor [mem], y
                            break;
                        case ArgumentType.DIRECT:
                            opcode = arguments[0].isZeroPage() ? 0x45 : 0x4D; // eor mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = arguments[0].isZeroPage() ? 0x55 : 0x5D; // eor mem, x
                            break;
                        case ArgumentType.INDEXED_BY_Y:
                            opcode = 0x59; // eor mem, y
                            break;
                    }
                    break;
                case BuiltinInstruction.BIT:
                    switch(arguments[0].getArgumentType())
                    {
                        case ArgumentType.DIRECT:
                            opcode = arguments[0].isZeroPage() ? 0x24 : 0x2C; // bit mem
                            break;
                    }
                    break;
                case BuiltinInstruction.INC:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.X:
                            opcode = 0xE8; // inx
                            break;
                        case ArgumentType.Y:
                            opcode = 0xC8; // iny
                            break;
                        case ArgumentType.DIRECT:
                            opcode = receiver.isZeroPage() ? 0xE6 : 0xEE; // inc mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = receiver.isZeroPage() ? 0xF6 : 0xFE; // inc mem, x
                            break;
                    }
                    break;
                case BuiltinInstruction.DEC:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.X:
                            opcode = 0xCA; // dex
                            break;
                        case ArgumentType.Y:
                            opcode = 0x88; // dey
                            break;
                        case ArgumentType.DIRECT:
                            opcode = receiver.isZeroPage() ? 0xC6 : 0xCE; // dec mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = receiver.isZeroPage() ? 0xD6 : 0xDE; // dec mem, x
                            break;
                    }
                    break;
                case BuiltinInstruction.SHL:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            opcode = 0x0A; // asl a
                            break;
                        case ArgumentType.DIRECT:
                            opcode = receiver.isZeroPage() ? 0x06 : 0x0E; // asl mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = receiver.isZeroPage() ? 0x16 : 0x1E; // asl mem, x
                            break;
                    }
                    break;
                case BuiltinInstruction.SHR:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            opcode = 0x4A; // lsr a
                            break;
                        case ArgumentType.DIRECT:
                            opcode = receiver.isZeroPage() ? 0x46 : 0x4E; // lsr mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = receiver.isZeroPage() ? 0x56 : 0x5E; // lsr mem, x
                            break;
                    }
                    break;
                case BuiltinInstruction.ROL:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            opcode = 0x2A; // rol a
                            break;
                        case ArgumentType.DIRECT:
                            opcode = receiver.isZeroPage() ? 0x26 : 0x2E; // rol mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = receiver.isZeroPage() ? 0x36 : 0x3E; // rol mem, x
                            break;
                    }
                    break;
                case BuiltinInstruction.ROR:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            opcode = 0x6A; // ror a
                            break;
                        case ArgumentType.DIRECT:
                            opcode = receiver.isZeroPage() ? 0x66 : 0x6E; // ror mem
                            break;
                        case ArgumentType.INDEXED_BY_X:
                            opcode = receiver.isZeroPage() ? 0x76 : 0x7E; // ror mem, x
                            break;
                    }
                    break;
                case BuiltinInstruction.PUSH:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            opcode = 0x48; // pha
                            break;
                        case ArgumentType.P:
                            opcode = 0x08; // php
                            break;
                    }
                    break;
                case BuiltinInstruction.PULL:
                    switch(receiver.getArgumentType())
                    {
                        case ArgumentType.A:
                            opcode = 0x68; // pla
                            break;
                        case ArgumentType.P:
                            opcode = 0x28; // plp
                            break;
                    }
                    break;
                case BuiltinInstruction.SET:
                    switch(arguments[0].getArgumentType())
                    {
                        case ArgumentType.CARRY:
                            opcode = 0x38; // sec
                            break;
                        case ArgumentType.INTERRUPT:
                            opcode = 0x78; // sei
                            break;
                        case ArgumentType.DECIMAL:
                            opcode = 0xF8; // sed
                            break;
                    }
                    break;
                case BuiltinInstruction.UNSET:
                    switch(arguments[0].getArgumentType())
                    {
                        case ArgumentType.CARRY:
                            opcode = 0x18; // clc
                            break;
                        case ArgumentType.INTERRUPT:
                            opcode = 0x58; // cli
                            break;
                        case ArgumentType.DECIMAL:
                            opcode = 0xD8; // cld
                            break;
                        case ArgumentType.OVERFLOW:
                            opcode = 0xB8; // clv
                            break;
                    }
                    break;
                case BuiltinInstruction.NOT:
                    defaultAssembly = false;
                    bank.writeByte(0x49, getPosition()); // eor #imm
                    bank.writeByte(0xFF, getPosition()); // with imm = 0xff
                    break;
                case BuiltinInstruction.NEG:
                    defaultAssembly = false;
                    bank.writeByte(0x18, getPosition()); // clc
                    bank.writeByte(0x49, getPosition()); // eor #imm
                    bank.writeByte(0xFF, getPosition()); // with imm = 0xff
                    bank.writeByte(0x69, getPosition()); // adc #imm
                    bank.writeByte(0x01, getPosition()); // with imm = 0x01
                    break;
            }
            
            if(defaultAssembly)
            {
                if(opcode)
                {
                    // Write opcode byte.
                    bank.writeByte(opcode, getPosition());
                    // Write receiver or argument, only one of which will have non-zero size.
                    receiver.write(bank);
                    if(arguments.length > 0)
                    {
                        arguments[0].write(bank);
                    }
                }
                else
                {
                    error("internal: output not generated for command", getPosition(), true);
                }
            }
        }
}