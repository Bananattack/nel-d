module nel.parse.parser;

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

static import std.conv;
static import std.path;
static import std.stdio;
static import std.string;
static import std.algorithm;

import nel.report;
import nel.ast.builtin;
import nel.ast.argument;
import nel.ast.attribute;
import nel.ast.statement;
import nel.ast.expression;
import nel.ast.if_statement;
import nel.ast.storage_type;
import nel.ast.data_statement;
import nel.ast.block_statement;
import nel.ast.embed_statement;
import nel.ast.while_statement;
import nel.ast.branch_statement;
import nel.ast.enum_declaration;
import nel.ast.header_statement;
import nel.ast.repeat_statement;
import nel.ast.command_statement;
import nel.ast.label_declaration;
import nel.ast.constant_declaration;
import nel.ast.relocation_statement;
import nel.ast.variable_declaration;
import nel.parse.token;
import nel.parse.scanner;

class Parser
{
    immutable uint INCLUDE_MAX = 16;
    
    enum StatementListType
    {
        BLOCK,
        IF,
        REPEAT
    }
    
    Scanner scanner;
    Scanner[] includeStack;
    Token token;
    string text;
    Keyword keyword;
    
    this(Scanner scanner)
    {
        this.scanner = scanner;
    }
    
    void nextToken()
    {
        token = scanner.next();
        text = scanner.getLastText();
        keyword = Keyword.NONE;
        if(token == Token.IDENTIFIER)
        {
            keyword = findKeyword(text);
        }
    }
    
    bool consume(Token expected)
    {
        if(token == expected)
        {
            nextToken();
            return true;
        }
        else
        {
            error("expected " ~ getSimpleTokenName(expected) ~ " but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
            nextToken();
            return false;
        }     
    }
    
    bool checkIdentifier(bool allowKeywords = false)
    {
        // If the token is a identifier and not a reserved word, then return its name.
        if(token == Token.IDENTIFIER && (!allowKeywords && keyword == Keyword.NONE || allowKeywords))
        {
            return true; 
        }
        // Otherwise, error and return null.
        else
        {
            error("expected identifier but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
            return false;
        }
    }
    
    bool checkIdentifier(Keyword[] permissibleKeywords)
    {
        checkIdentifier(true);
        
        if(keyword == Keyword.NONE || std.algorithm.find(permissibleKeywords, keyword).length > 0)
        {
            return true;
        }
        else
        {
            string[] keywordNames = [];
            foreach(keyword; permissibleKeywords)
            {
                keywordNames ~= "keyword '" ~ getKeywordName(keyword) ~ "'";
            }
            keywordNames[keywordNames.length - 1] = "or " ~ keywordNames[keywordNames.length - 1];
            
            error("expected identifier, " ~ std.algorithm.reduce!("a ~ \", \" ~ b")(keywordNames) ~ ", but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
            return false;
        }
    }
    
    BlockStatement parse()
    {
        nextToken();
        return handleProgram();
    }
    
    BlockStatement handleProgram()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        Statement[] statements;
        while(1)
        {
            if(token == Token.IDENTIFIER && keyword == Keyword.END)
            {
                error("unexpected 'end'", scanner.getPosition());
                nextToken();
            }
            if(token == Token.EOF)
            {
                if(includeStack.length == 0)
                {
                    break;
                }
                else
                {
                    // Pop previous scanner off stack.
                    uint top = includeStack.length - 1;
                    scanner = includeStack[top];
                    includeStack.length = top;
                    // Ready a new token for the scanner.
                    nextToken();
                }
            }
            
            Statement statement = handleStatement();
            if(statement !is null)
            {
                statements ~= statement;
            }
        }
        return new BlockStatement(BlockType.MAIN, statements, position);
    }
    
    Statement[] handleStatementList(StatementListType statementListType = StatementListType.BLOCK)
    {
        Statement[] statements;
        while(1)
        {
            if(token == Token.EOF)
            {
                error("expected 'end', but got end-of-file.", scanner.getPosition());
                return null;
            }
            if(statementListType == StatementListType.IF)
            {
                if(keyword == Keyword.END || keyword == Keyword.ELSE || keyword == Keyword.ELSEIF)
                {
                    // Don't consume the token, but keep it around, so we can check for it in the if statement.
                    return statements;
                }
                else if(keyword == Keyword.UNTIL)
                {
                    error("expected statement, 'else', 'endif', or 'end', but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                }
            }
            else if(statementListType == StatementListType.REPEAT)
            {
                if(keyword == Keyword.END || keyword == Keyword.UNTIL)
                {
                    // Don't consume the token, but keep it around, so we can check for it in the if statement.
                    return statements;
                }
                else if(keyword == Keyword.ELSE || keyword == Keyword.ELSEIF)
                {
                    error("expected statement, 'end', or 'until', but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                }
            }
            else if(statementListType == StatementListType.BLOCK)
            {
                if(keyword == Keyword.END)
                {
                    nextToken();
                    return statements;
                }
                else if(keyword == Keyword.UNTIL || keyword == Keyword.ELSE || keyword == Keyword.ELSEIF)
                {
                    error("expected statement or 'end', but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                }
            }
            
            Statement statement = handleStatement();
            if(statement !is null)
            {
                statements ~= statement;
            }
        }
    }
    
    Statement handleStatement()
    {
        switch(token)
        {
            case Token.IDENTIFIER:
                switch(keyword)
                {
                    case Keyword.INES:
                        return handleHeaderStatement();
                    case Keyword.INCLUDE:
                        handleInclude();
                        return null;
                    case Keyword.EMBED:
                        return handleEmbedStatement();
                    case Keyword.ROM:
                    case Keyword.RAM:
                        return handleRelocationStatement();
                    case Keyword.BEGIN:
                    case Keyword.PACKAGE:
                        return handleBlockStatement();
                    case Keyword.DEF:
                        return handleLabelDeclaration();
                    case Keyword.LET:
                        return handleConstantDeclaration();
                    case Keyword.ENUM:
                        return handleEnumDeclaration();
                    case Keyword.VAR:
                        return handleVariableDeclaration();
                    case Keyword.BYTE:
                    case Keyword.WORD:
                        return handleDataStatement();
                    case Keyword.GOTO:
                    case Keyword.CALL:
                    case Keyword.RETURN:
                    case Keyword.RESUME:
                    case Keyword.NOP:
                        return handleBranchStatement();
                    case Keyword.IF:
                        return handleIfStatement();
                    case Keyword.WHILE:
                        return handleWhileStatement();
                    case Keyword.REPEAT:
                        return handleRepeatStatement();
                    case Keyword.ELSE:
                    case Keyword.ELSEIF:
                    case Keyword.END:
                        // 'end' keyword. Done statement list possibly.
                        return null;
                    case Keyword.NONE:
                        // Unknown identifier. Assume command statement.
                        return handleCommandStatement();
                    default:
                        error("expected statement, but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                        nextToken();
                        break;
                }
                break;
            case Token.PUNC_LPAREN:
            case Token.OP_LT:
            case Token.OP_GT:
            case Token.PUNC_EXCLAIM:
            case Token.INTEGER:
            case Token.HEXADECIMAL:
            case Token.BINARY:
                // A dangling number. Treat as (invalid) command for now (which will do more thorough error checking).
                handleCommandStatement();
                break;
            case Token.PUNC_AT:
            case Token.PUNC_HASH:
                return handleCommandStatement();
            case Token.PUNC_SEMI:
                // semi-colon, skip.
                nextToken();
                break;
            default:
                error("expected statement, but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                nextToken();
                break;
        }
        return null;
    }
        
    HeaderStatement handleHeaderStatement()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        
        nextToken(); // IDENTIFIER (keyword 'ines')
        consume(Token.PUNC_COLON);
        
        HeaderSegment[] segments;
        // IDENTIFIER '=' expr (',' IDENTIFIER '=' expr)*
        while(true)
        {
            SourcePosition segmentPosition = new SourcePosition(scanner.getPosition());
            string name;
            Expression value;
            
            if(checkIdentifier())
            {
                name = text;
            }
            nextToken(); // IDENTIFIER
            consume(Token.OP_EQ); // =
            value = handleExpr(); // expr
            
            segments ~= new HeaderSegment(name, value, segmentPosition);
            if(token == Token.PUNC_COMMA)
            {
                nextToken(); // ,
                continue;
            }
            return new HeaderStatement(segments, position);
        }
    }
        
    void handleInclude()
    {
        nextToken(); // IDENTIFIER (keyword 'include')
        
        string filename = null;
        // STRING
        if(token == Token.STRING)
        {
            // Don't call nextToken() here, we'll be doing that when the scanner's popped off later.
            filename = text;
        }
        else
        {
            consume(Token.STRING);
            return;
        }
        
        // Make the filename relative to its current source.
        filename = std.path.dirname(scanner.getPosition().getFile().getFilename()) ~ std.path.sep ~ filename;        
        
        if(includeStack.length > INCLUDE_MAX)
        {
            string message = "exceeded max include depth while attempting to include " ~ filename ~ "." ~ std.string.newline;
            message ~= "  (are there mutually dependent includes somewhere?)" ~ std.string.newline;
            // Dump stack.
            for(uint i = 0; i < includeStack.length; i++)
            {
                message ~= "    " ~ includeStack[i].getPosition().toString() ~ std.string.newline;
            }
            message ~= "    " ~ scanner.getPosition().toString();
            error(message, scanner.getPosition(), true);
            return;
        }
        
        // Push old scanner onto stack.
        includeStack ~= scanner;
        
        // Open the new file.
        std.stdio.File file;
        try
        {
            file = std.stdio.File(filename, "rb");
        }
        catch(Exception e)
        {
            // If file fails to open, then file will be not be open. Ignore exceptions.
        }
        if(file.isOpen())
        {
            // Swap scanner.
            scanner = new Scanner(file, filename);
        }
        else
        {
            error("could not include file '" ~ filename ~ "'", scanner.getPosition(), true);
        }
        // Now, ready the next token.
        nextToken();
    }
    
    EmbedStatement handleEmbedStatement()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        nextToken(); // IDENTIFIER (keyword 'embed')
        
        // STRING
        if(token == Token.STRING)
        {
            string filename = text;
            nextToken();
            
            // Make the filename relative to its current source.
            filename = std.path.dirname(scanner.getPosition().getFile().getFilename()) ~ std.path.sep ~ filename;   
            return new EmbedStatement(filename, position);
        }
        else
        {
            consume(Token.STRING);
            return null;
        }
    }
    
    RelocationStatement handleRelocationStatement()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        RelocationStatement statement;
        switch(keyword)
        {
            case Keyword.ROM:
                nextToken(); // IDENTIFIER (keyword 'rom')
                // rom bank expr
                if(keyword == Keyword.BANK)
                {
                    nextToken(); // IDENTIFIER (keyword 'bank')
                    Expression bank = handleExpr(); // expr
                    Expression location;
                    
                    // (, expr)?
                    if(token == Token.PUNC_COMMA)
                    {
                        nextToken(); // ,
                        location = handleExpr(); // expr
                    }
                    statement = new RelocationStatement(bank, location, position);
                }
                // rom expr
                else
                {
                    Expression location = handleExpr(); // expr
                    statement = new RelocationStatement(RelocationType.ROM, location, position);
                }
                break;
            case Keyword.RAM:
                nextToken(); // IDENTIFIER (keyword 'ram')
                
                // rom doesn't have banks, read the input but raise an error.
                if(keyword == Keyword.BANK)
                {
                    error("'ram' statement found with 'bank' keyword, but ram does not allow banking. did you mean to write 'rom'?", scanner.getPosition());
                    
                    nextToken(); // IDENTIFIER (keyword 'bank')
                    handleExpr(); // expr
                    
                    // (, expr)?
                    if(token == Token.PUNC_COMMA)
                    {
                        nextToken(); // ,
                        handleExpr(); // expr
                    }
                }
                else
                {
                    Expression location = handleExpr(); // expr
                    statement = new RelocationStatement(RelocationType.RAM, location, position);
                }
                break;
        }
        
        consume(Token.PUNC_COLON); // :
        return statement;
    }
    
    BlockStatement handleBlockStatement()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        switch(keyword)
        {
            case Keyword.BEGIN:
                nextToken(); // IDENTIFIER (keyword 'begin')
                Statement[] statements = handleStatementList(); // statement list (which also handles the 'end')
                return new BlockStatement(BlockType.SCOPE, statements, position);
            case Keyword.PACKAGE:
                string name;
                
                nextToken(); // IDENTIFIER (keyword 'package')
                if(checkIdentifier())
                {
                    name = text;
                }
                nextToken(); // IDENTIFIER
                Statement[] statements = handleStatementList(); // statement list (which also handles the 'end')
                return new BlockStatement(BlockType.SCOPE, name, statements, position);
        }
    }
    
    LabelDeclaration handleLabelDeclaration()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        
        string name;
        
        nextToken(); // IDENTIFIER (keyword 'def')
        if(checkIdentifier())
        {
            name = text;
        }
        nextToken(); // IDENTIFIER
        consume(Token.PUNC_COLON);
        
        return new LabelDeclaration(name, position);
    }
    
    ConstantDeclaration handleConstantDeclaration()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        
        string name;
        StorageType storage = StorageType.WORD;
        Expression value;
        
        nextToken(); // IDENTIFIER (keyword 'let')
        if(checkIdentifier())
        {
            name = text;
        }
        nextToken(); // IDENTIFIER
        
        // (':' ('byte'|'word'))?
        if(token == Token.PUNC_COLON)
        {
            consume(Token.PUNC_COLON); // :
            if(checkIdentifier(true))
            {
                switch(keyword)
                {
                    case Keyword.BYTE:
                        storage = StorageType.BYTE;
                        break;
                    case Keyword.WORD:
                        storage = StorageType.WORD;
                        break;
                    default:
                        error("unknown storage specifier '" ~ text ~ "'. only 'byte' and 'word' are allowed.", scanner.getPosition());
                }
                nextToken(); // IDENTIFIER (keyword 'byte'/'word')
            }
            else
            {
                error("expected a storage specifier after ':' in constant declaration, but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                if(token != Token.OP_EQ)
                {
                    nextToken();
                }
            }        
        }
        consume(Token.OP_EQ); // =
        value = handleExpr(); // expr
        
        return new ConstantDeclaration(name, value, storage, position);
    }
    
    EnumDeclaration handleEnumDeclaration()
    {
        SourcePosition enumPosition = new SourcePosition(scanner.getPosition());
        
        SourcePosition constantPosition = enumPosition;
        string name;
        Expression value;
        uint offset;
        ConstantDeclaration[] constants;
        StorageType storage = StorageType.WORD;
        
        nextToken(); // IDENTIFIER (keyword 'enum')
        consume(Token.PUNC_COLON); // :
        
        // (('byte' | 'word') ':')? IDENTIFIER
        if(checkIdentifier(true))
        {
            switch(keyword)
            {
                case Keyword.BYTE:
                    storage = StorageType.BYTE;
                    nextToken(); // IDENTIFIER (keyword 'byte')
                    consume(Token.PUNC_COLON); // :
                    if(checkIdentifier(true))
                    {
                        name = text;
                    }
                    constantPosition = new SourcePosition(scanner.getPosition());
                    nextToken(); // IDENTIFIER
                    break;
                case Keyword.WORD:
                    storage = StorageType.WORD;
                    nextToken(); // IDENTIFIER (keyword 'word')
                    consume(Token.PUNC_COLON); // :
                    if(checkIdentifier(true))
                    {
                        name = text;
                    }
                    constantPosition = new SourcePosition(scanner.getPosition());
                    nextToken(); // IDENTIFIER
                    break;
                default:
                    Token lastToken = token;
                    if(checkIdentifier(true))
                    {
                        name = text;
                    }
                    constantPosition = new SourcePosition(scanner.getPosition());
                    nextToken(); // IDENTIFIER
                    
                    if(token == Token.PUNC_COLON)
                    {
                        error("expected storage specifier, but got " ~ getVerboseTokenName(lastToken, name) ~ ". only 'byte' and 'word' are allowed.", scanner.getPosition());
                        consume(Token.PUNC_COLON); // :
                        if(checkIdentifier(true))
                        {
                            name = text;
                        }
                        constantPosition = new SourcePosition(scanner.getPosition());
                        nextToken(); // IDENTIFIER
                    }
            }
        }
        
        // ('=' expr)?
        if(token == Token.OP_EQ)
        {
            consume(Token.OP_EQ); // =
            value = handleExpr(); // expr
        }
        else
        {
            value = new NumericExpression(0, NumericType.INTEGER, constantPosition);
        }
        constants ~= new ConstantDeclaration(name, value, offset++, storage, constantPosition);
        
        // (',' name ('=' expr)?)*
        bool more = token == Token.PUNC_COMMA;
        while(more)
        {
            nextToken(); // ,
            if(token == Token.IDENTIFIER)
            {
                if(checkIdentifier())
                {
                    name = text;
                }
                constantPosition = new SourcePosition(scanner.getPosition());
                nextToken(); // IDENTIFIER
                // ('=' expr)?
                if(token == Token.OP_EQ)
                {
                    consume(Token.OP_EQ); // =
                    value = handleExpr();
                    offset = 0; // If we explicitly set a value, then we reset the enum expression offset.
                }
                
                constants ~= new ConstantDeclaration(name, value, offset++, storage, constantPosition);
                // Check if we should match (',' id)*
                more = token == Token.PUNC_COMMA;
            }
            else
            {
                error("expected identifier after ',' in enum declaration, but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                more = false;
            }
        }
        
        return new EnumDeclaration(constants, enumPosition);
    }
    
    VariableDeclaration handleVariableDeclaration()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        
        string[] names;
        StorageType storage;
        Expression arraySize;
        
        nextToken(); // IDENTIFIER (keyword 'var')
        
        if(checkIdentifier())
        {
            names ~= text;
        }
        nextToken(); // IDENTIFIER
        
        // Check if we should match (',' id)*
        bool more = token == Token.PUNC_COMMA;
        while(more)
        {
            nextToken(); // ,
            if(token == Token.IDENTIFIER)
            {
                if(checkIdentifier())
                {
                    // handle name
                    names ~= text;
                }
                nextToken(); // IDENTIFIER
                
                // Check if we should match (',' id)*
                more = token == Token.PUNC_COMMA;
            }
            else
            {
                error("expected identifier after ',' in variable declaration, but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                more = false;
            }
        }
        
        consume(Token.PUNC_COLON); // :
        if(checkIdentifier(true))
        {
            switch(keyword)
            {
                case Keyword.BYTE:
                    storage = StorageType.BYTE;
                    break;
                case Keyword.WORD:
                    storage = StorageType.WORD;
                    break;
                default:
                    error("unknown storage specifier '" ~ text ~ "'. only 'byte' and 'word' are allowed.", scanner.getPosition());
            }
        }
        else
        {
            error("expected a storage specifier after ':' in variable declaration, but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
        }        
        nextToken(); // IDENTIFIER (keyword 'byte'/'word')
        // ('[' array_size ']')?
        if(token == Token.PUNC_LBRACKET)
        {
            nextToken(); // [
            arraySize = handleExpr(); // expr
            consume(Token.PUNC_RBRACKET); // ]
        }

        return new VariableDeclaration(names, storage, arraySize, position);
    }
    
    DataStatement handleDataStatement()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        StorageType storage;
        switch(keyword)
        {
            case Keyword.BYTE:
                storage = StorageType.BYTE;
                break;
            case Keyword.WORD:
                storage = StorageType.WORD;
                break;
        }
        nextToken(); // IDENTIFIER (keyword 'byte'/'word')
        consume(Token.PUNC_COLON);
        
        DataItem[] items;

        // item (',' item)*
        while(true)
        {
            if(token == Token.STRING)
            {
                items ~= new StringDataItem(text, scanner.getPosition()); // STRING
                nextToken();
            }
            else
            {
                SourcePosition itemPosition = new SourcePosition(scanner.getPosition());
                Expression expr = handleExpr(); // expr
                items ~= new NumericDataItem(expr, itemPosition);
            }
            // (',' item)*
            if(token == Token.PUNC_COMMA)
            {
                nextToken(); // ,
                continue;
            }
            break;
        }
        return new DataStatement(storage, items, position);
    }
    
    BranchStatement handleBranchStatement()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        switch(keyword)
        {
            case Keyword.GOTO:
                nextToken(); // IDENTIFIER (keyword 'goto')
                
                bool indirect;
                
                Argument destination;
                // goto [indirect]
                if(token == Token.PUNC_LBRACKET)
                {
                    indirect = true;
                    nextToken(); // [
                    SourcePosition argumentPosition = scanner.getPosition();
                    destination = new Argument(ArgumentType.INDIRECT, handleExpr(), argumentPosition); // expr
                    consume(Token.PUNC_RBRACKET); // ]
                }
                // goto direct
                else
                {
                    SourcePosition argumentPosition = scanner.getPosition();
                    destination = new Argument(ArgumentType.DIRECT, handleExpr(), argumentPosition); // expr
                }
                
                BranchCondition condition = null;
                if(token == Token.IDENTIFIER && keyword == Keyword.WHEN)
                {                    
                    if(indirect)
                    {
                        error("'when' clause is not allowed on indirect 'goto'", scanner.getPosition());
                    }
                    nextToken(); // IDENTIFIER (keyword 'when')
                    condition = handleBranchCondition("'when'");
                }
                return new BranchStatement(BranchType.GOTO, destination, condition, position);
            case Keyword.CALL:
                nextToken(); // IDENTIFIER (keyword 'call')
                SourcePosition argumentPosition = scanner.getPosition();
                Argument destination = new Argument(ArgumentType.DIRECT, handleExpr(), argumentPosition); // expr
                return new BranchStatement(BranchType.CALL, destination, position);
            case Keyword.RETURN:
                nextToken(); // IDENTIFIER (keyword 'return')
                return new BranchStatement(BranchType.RETURN, position);
            case Keyword.RESUME:
                nextToken(); // IDENTIFIER (keyword 'resume')
                return new BranchStatement(BranchType.RESUME, position);
            case Keyword.NOP:
                nextToken(); // IDENTIFIER (keyword 'nop')
                return new BranchStatement(BranchType.NOP, position);
        }
    }
    
    BranchCondition handleBranchCondition(string context)
    {
        BranchCondition condition = null;
        
        // 'not'* (not isn't a keyword, but it has special meaning)
        bool negated = false;
        while(keyword == Keyword.NOT)
        {
            nextToken(); // IDENTIFIER (keyword 'not')
            negated = !negated;
        }
        
        if(token == Token.IDENTIFIER && checkIdentifier())
        {
            ArgumentType flag = findBuiltinFlag(text);
            if(flag == ArgumentType.NONE)
            {
                error("unrecognized flag name '" ~ text ~ "' directly after " ~ context, scanner.getPosition());
            }
            condition = new BranchCondition(negated, new Argument(flag, scanner.getPosition()), scanner.getPosition());
            nextToken(); // IDENTIFIER
        }
        else
        {
            ArgumentType flag = ArgumentType.NONE;
            switch(token)
            {
                case Token.OP_NE:
                    // when ... <> is same as when ... not zero
                    negated = !negated;
                    flag = ArgumentType.ZERO;
                    nextToken(); // <>
                    break;
                case Token.OP_EQ:
                    // when ... = is same as when ... zero
                    flag = ArgumentType.ZERO;
                    nextToken(); // =
                    break;
                case Token.OP_LT:
                    negated = !negated;
                    flag = ArgumentType.CARRY;
                    nextToken(); // <
                    break;
                case Token.OP_GE:
                    flag = ArgumentType.CARRY;
                    nextToken(); // >=
                    break;
                default:
                    error("expected flag name directly after " ~ context ~ ", but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
            }
            
            condition = new BranchCondition(negated, new Argument(flag, scanner.getPosition()), scanner.getPosition());
        }
        return condition;
    }
    
    IfStatement handleIfStatement()
    {
        IfStatement first = null;
        IfStatement statement = null;
        
        // 'if' (condition | expr) 'then' statement* ('elseif' (condition | expr) 'then' statement*)*
        do
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            nextToken(); // IDENTIFIER (keyword 'if' / 'elseif')
            
            Expression expression = null;
            BranchCondition condition = null;
            
            // condition | expr
            switch(token)
            {
                case Token.IDENTIFIER:
                    // if the token is not a flag or expression, error.
                    ArgumentType flag = findBuiltinFlag(text);
                    
                    if(flag != ArgumentType.NONE || keyword == Keyword.NOT)
                    {
                        condition = handleBranchCondition("'if'"); // condition
                    }
                    else
                    {
                        expression = handleExpr(); // expr
                    }
                    break;
                case Token.OP_LT:
                    // Uh oh. '<' could be a condition, or a byte-masking unary operator depending on the following tokens!
                    SourcePosition expressionPosition = new SourcePosition(scanner.getPosition());
                    
                    condition = new BranchCondition(true, new Argument(ArgumentType.CARRY, scanner.getPosition()), scanner.getPosition());
                    nextToken(); // <
                    // If the next token isn't 'then', we should treat it as an operand of the byte-masking op <, and not as less-than / 'carry'
                    if(keyword != Keyword.THEN)
                    {   
                        condition = null;
                        expression = new UnaryOperatorExpression(UnaryOperatorType.BYTE_LOW, handleTerm(), expressionPosition); // term
                    }
                    break;
                case Token.OP_GE:
                case Token.OP_NE:
                case Token.OP_EQ:
                    condition = handleBranchCondition("'if'"); // condition
                    break;
                case Token.PUNC_LPAREN:
                case Token.OP_GT:
                case Token.PUNC_EXCLAIM:
                case Token.INTEGER:
                case Token.HEXADECIMAL:
                case Token.BINARY:
                    expression = handleExpr(); // expr
                    break;
            }
            
            if(keyword != Keyword.THEN)
            {
                error("expected 'then', but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
            }
            nextToken(); // IDENTIFIER (keyword 'then')
            
            // statement*
            BlockStatement block = new BlockStatement(BlockType.SCOPE, handleStatementList(StatementListType.IF), position);
            
            // Construct if statement, which is either static or runtime depending on argument before 'then'.
            IfStatement previous = statement;
            if(expression !is null)
            {
                statement = new StaticIfStatement(expression, block, position);
            }
            else if(condition !is null)
            {
                statement = new RuntimeIfStatement(condition, block, position);
            }

            // If this is an 'elseif', join to previous 'if'/'elseif'.
            if(previous !is null)
            {
                previous.setFalseBranch(statement);
            }
            else if(first is null)
            {
                first = statement;
            }
        } while(keyword == Keyword.ELSEIF);
        
        // ('else' statement*)? 'end' (with error recovery for invalid else/elseif placements)
        if(keyword == Keyword.ELSE)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            nextToken(); // IDENTIFIER (keyword 'else')
            statement.setFalseBranch(new BlockStatement(BlockType.SCOPE, handleStatementList(StatementListType.IF), position)); // statement*
        }
        switch(keyword)
        {
            case Keyword.ELSE:
                error("duplicate 'else' clause found.", scanner.getPosition());
                break;
            case Keyword.ELSEIF:
                // Seeing as we loop on elseif before an else/end, this must be an illegal use of elseif.
                error("'elseif' can't appear after 'else' clause.", scanner.getPosition());
                break;
            default:
        }
        if(keyword != Keyword.END)
        {
            error("expected 'end', but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
        }
        nextToken(); // IDENTIFIER (keyword 'end')
        return first;
    }
    
    WhileStatement handleWhileStatement()
    {
        // 'while' condition ('then' | 'do') statement* 'end'
        SourcePosition position = new SourcePosition(scanner.getPosition());
        nextToken(); // IDENTIFIER (keyword 'if' / 'elseif')
        
        BranchCondition condition = handleBranchCondition("'while'");
        if(keyword != Keyword.THEN && keyword != Keyword.DO)
        {
            error("expected 'then' or 'do', but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
        }
        nextToken(); // IDENTIFIER (keyword 'then'/'do')
        
        BlockStatement block = new BlockStatement(BlockType.SCOPE, handleStatementList(), position); // statement*

        return new WhileStatement(condition, block, position);
    }
    
    RepeatStatement handleRepeatStatement()
    {
        // 'repeat' statement* 'until' condition
        SourcePosition position = new SourcePosition(scanner.getPosition());
        nextToken(); // IDENTIFIER (keyword 'if' / 'elseif')
        
        BlockStatement block = new BlockStatement(BlockType.SCOPE, handleStatementList(StatementListType.REPEAT), position); // statement*
        
        BranchCondition condition = null;
        switch(keyword)
        {
            case Keyword.END:
                nextToken(); // IDENTIFIER (keyword 'end')
                break;
            case Keyword.UNTIL:
                nextToken(); // IDENTIFIER (keyword 'until')
                condition = handleBranchCondition("'until'");
                break;
            default:
                error("expected 'end' or 'until', but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
        }
        
        return new RepeatStatement(condition, block, position);
    }
    
    CommandStatement handleCommandStatement()
    {
        string receiverName = "";
        ArgumentType register = ArgumentType.NONE;
        ArgumentType flag = ArgumentType.NONE;
        Argument receiver = null;
        Expression dangler = null;
        
        switch(token)
        {
            case Token.IDENTIFIER:
                // if the token is not a register, error.
                register = findBuiltinRegister(text);
                flag = findBuiltinFlag(text);
                receiverName = text;
                
                if(register != ArgumentType.NONE)
                {
                    receiver = handleArgument(); // arg
                }
                else
                {
                    dangler = handleExpr(); // expr
                }
                break;
            case Token.PUNC_AT:
            case Token.PUNC_HASH:
                receiver = handleArgument(); // arg
                break;
            case Token.PUNC_LPAREN:
            case Token.OP_LT:
            case Token.OP_GT:
            case Token.PUNC_EXCLAIM:
            case Token.INTEGER:
            case Token.HEXADECIMAL:
            case Token.BINARY:
                dangler = handleExpr(); // expr
                break;
        }
        
        Command[] commands;
        while(true)
        {
            // If there's a dangling expression, then the colon is optional (skip over commands if present).
            // But if the receiver argument is valid, then expect a colon.
            if(token == Token.PUNC_COLON)
            {
                if(receiver is null)
                {
                    error("illegal use of unprefixed expression in command statement. did you make a typo, or forget @ or #?", scanner.getPosition());
                }
                nextToken(); // :
                
                Argument oldReceiver = receiver;
                // Replace this with the receiver argument node.
                commands ~= handleCommand(receiver); // command.
                // (',' command)*
                while(token == Token.PUNC_COMMA)
                {
                    nextToken();
                    commands ~= handleCommand(receiver); // command.
                    
                    // break so the change in receiver can be handled.
                    if(oldReceiver != receiver)
                    {
                        break;
                    }
                }
                // Found another command statement in the process of parsing command list.
                if(oldReceiver != receiver)
                {
                    continue;
                }
            }
            else 
            {
                if(receiver is null)
                {
                    error("expected statement, but found dangling expression" ~ (dangler !is null ? " '" ~ dangler.toString() ~ "'" : "") ~ " before " ~ getVerboseTokenName(token, text) ~ ".", scanner.getPosition());
                }
                else
                {
                    if(register != ArgumentType.NONE)
                    {
                        error("expected statement, but found dangling register reference '" ~ receiverName ~ "'.", scanner.getPosition());
                    }
                    else if(flag != ArgumentType.NONE)
                    {
                        error("expected statement, but found dangling flag reference '" ~ receiverName ~ "'.", scanner.getPosition());
                    }
                    else
                    {
                        error("expected statement, but found dangling argument before " ~ getVerboseTokenName(token, text) ~ ". did you forget a colon?", scanner.getPosition());
                    }
                }
            }
            if(commands.length == 0)
            {
                return null;
            }
            else
            {
                return new CommandStatement(commands, scanner.getPosition());
            }
        }
    }
    
    Command handleCommand(ref Argument receiver)
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        BuiltinInstruction instruction = BuiltinInstruction.NONE;
        
        if(checkIdentifier([Keyword.NOT]))
        {
            instruction = findBuiltinInstruction(text);
            if(instruction == BuiltinInstruction.NONE)
            {
                error("unrecognized command name '" ~ text ~ "'", scanner.getPosition());
            }
            
            nextToken(); // IDENTIFIER
        }
        else
        {
            nextToken(); // UNKNOWN
            return null;
        }
        
        Argument[] arguments;
        // command(argument_list)
        if(token == Token.PUNC_LPAREN)
        {
            nextToken(); // (
            // argument?
            if(token != Token.PUNC_RPAREN)
            {
                arguments ~= handleArgument(); // argument
                // (',' argument)*
                while(token == Token.PUNC_COMMA)
                {
                    nextToken(); // ,
                    arguments ~= handleArgument();
                }
            }
            consume(Token.PUNC_RPAREN); // )
            
            // Return the command.
            return instruction != BuiltinInstruction.NONE
                ? new InstructionCommand(instruction, receiver, arguments, position)
                : null;
        }
        // command single_arg?
        // Some special handling is needed to prevent an ambiguity between the optional argument
        // and a possible receiver of a new command statement.
        else
        {
            Argument argument = null;
            // token might be the optional argument. check!
            switch(token)
            {
                case Token.IDENTIFIER:
                    // argument shouldn't be a keyword, obviously.
                    if(keyword == Keyword.NONE)
                    {
                        argument = handleArgument(); // argument
                    }
                    break;
                case Token.PUNC_AT:
                case Token.PUNC_HASH:
                    argument = handleArgument(); // argument
                    break;
                default:
                    // No argument.
                    break;
            }
            
            // Make a local copy of the receiver, because it might change soon.
            Argument oldReceiver = receiver;
            
            // Did we get an argument?
            if(argument !is null)
            {
                // If the next token is a colon, then this argument doesn't belong to this statement.
                if(token == Token.PUNC_COLON)
                {
                    // Change the receiver reference, and don't use this argument yet.
                    receiver = argument;
                }
                else
                {
                    arguments ~= argument;
                }
            }
            // Return the command.
            return instruction != BuiltinInstruction.NONE
                ? new InstructionCommand(instruction, oldReceiver, arguments, position)
                : null;
        }
    }
    
    Argument handleArgument()
    {
        Expression dangler;
        switch(token)
        {
            case Token.IDENTIFIER:
                // if the token is not a register/flag, error.
                ArgumentType register = findBuiltinRegister(text);
                ArgumentType flag = findBuiltinFlag(text);
                if(register != ArgumentType.NONE)
                {
                    Argument argument = new Argument(register, scanner.getPosition());
                    nextToken(); // IDENTIFIER
                    return argument;
                }
                else if(flag != ArgumentType.NONE)
                {
                    Argument argument = new Argument(flag, scanner.getPosition());
                    nextToken(); // IDENTIFIER;
                    return argument;
                }
                else
                {
                    dangler = handleExpr(); // expr
                    error("expected register name or conditional flag, but got expression" ~ (dangler !is null ? " '" ~ dangler.toString() ~ "'" : "") ~ ". did you forget @ or #?", scanner.getPosition());
                    return null;
                }
            case Token.PUNC_AT:
                SourcePosition position = new SourcePosition(scanner.getPosition());
                nextToken(); // @
                
                ArgumentType argumentType = ArgumentType.NONE;
                Expression expr;
                
                bool indirect = false;
                bool pre = false;
                bool post = false;
                // @[expr[x]] or @[expr][y] (post-indexing handled later)
                if(token == Token.PUNC_LBRACKET)
                {
                    nextToken(); // [
                    indirect = true;
                    expr = handleExpr(); // expr
                    if(token == Token.PUNC_LBRACKET)
                    {
                        pre = true;
                        nextToken(); // [
                        
                        if(checkIdentifier())
                        {
                            // expect 'x'
                            ArgumentType register = findBuiltinRegister(text);
                            if(register == ArgumentType.X)
                            {
                                argumentType = ArgumentType.INDEXED_BY_X_INDIRECT;
                            }
                            else
                            {
                                error("indirect memory term can only be pre-indexed by 'x', not " ~ getVerboseTokenName(token, text), scanner.getPosition());
                            }
                        }
                        nextToken(); // IDENTIFIER
                        consume(Token.PUNC_RBRACKET); // ]
                    }
                    consume(Token.PUNC_RBRACKET); // ]
                }
                // @expr
                else
                {
                    argumentType = ArgumentType.DIRECT;
                    expr = handleExpr(); // expr
                }
                
                // indexing by x or y for direct, post-indexing by y for indirect
                if(token == Token.PUNC_LBRACKET)
                {
                    post = true;
                    if(indirect && pre)
                    {
                        error("indirect memory term cannot be both pre-indexed and post-indexed", scanner.getPosition());
                    }
                    nextToken(); // [
                    
                    if(checkIdentifier())
                    {
                        // expect 'x' or 'y' (but 'x' only allowed if not indirected for post-indexed)
                        ArgumentType register = findBuiltinRegister(text);
                        if(indirect)
                        {
                            if(register == ArgumentType.Y)
                            {
                                argumentType = ArgumentType.INDIRECT_INDEXED_BY_Y;
                            }
                            else
                            {
                                error("indirect memory term can only be post-indexed by 'y', not " ~ getVerboseTokenName(token, text), scanner.getPosition());
                            }
                        }
                        else
                        {
                            if(register == ArgumentType.X)
                            {
                                argumentType = ArgumentType.INDEXED_BY_X;
                            }
                            else if(register == ArgumentType.Y)
                            {
                                argumentType = ArgumentType.INDEXED_BY_Y;
                            }
                            else
                            {
                                error("direct memory term can only be indexed by 'x' or 'y', not " ~ getVerboseTokenName(token, text), scanner.getPosition());
                            }
                        }
                    }
                    nextToken(); // IDENTIFIER
                    consume(Token.PUNC_RBRACKET); // ]
                }
                if(indirect && !pre && !post)
                {
                    error("indirect memory term must be pre-indexed or post-indexed.", scanner.getPosition());
                }
                return new Argument(argumentType, expr, position);
            case Token.PUNC_HASH:
                SourcePosition position = new SourcePosition(scanner.getPosition());
                nextToken(); // #
                Expression expr = handleExpr(); // expr
                return new Argument(ArgumentType.IMMEDIATE, expr, position);
            case Token.PUNC_LPAREN:
            case Token.OP_LT:
            case Token.OP_GT:
            case Token.PUNC_EXCLAIM:
            case Token.INTEGER:
            case Token.HEXADECIMAL:
            case Token.BINARY:
                dangler = handleExpr(); // expr
                error("expected register name or conditional flag, but got expression" ~ (dangler !is null ? " '" ~ dangler.toString() ~ "'" : "") ~ ". did you forget @ or #?", scanner.getPosition());
                return null;
            default:
                return null;
        }
    }
    
    Expression handleExpr()
    {
        return handleLogicalOrExpr(); // logical or
    }
    
    Expression handleLogicalOrExpr()
    {
        Expression left = handleLogicalAndExpr(); // logical and
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_OR_OR:
                    nextToken(); // ||
                    Expression right = handleLogicalAndExpr(); // logical and
                    left = new BinaryOperatorExpression(BinaryOperatorType.LOGICAL_OR, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }
    
    Expression handleLogicalAndExpr()
    {
        Expression left = handleBitwiseOrExpr(); // bitwise or
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_AND_AND:
                    nextToken(); // &&
                    Expression right = handleBitwiseOrExpr(); // bitwise or
                    left = new BinaryOperatorExpression(BinaryOperatorType.LOGICAL_AND, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }
    
    Expression handleBitwiseOrExpr()
    {
        Expression left = handleBitwiseXorExpr(); // bitwise xor
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_OR:
                    nextToken(); // |
                    Expression right = handleBitwiseXorExpr(); // bitwise xor
                    left = new BinaryOperatorExpression(BinaryOperatorType.BITWISE_OR, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }
    
    Expression handleBitwiseXorExpr()
    {
        Expression left = handleBitwiseAndExpr(); // bitwise and
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_XOR:
                    nextToken(); // ^
                    Expression right = handleBitwiseAndExpr(); // bitwise and
                    left = new BinaryOperatorExpression(BinaryOperatorType.BITWISE_XOR, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }
    
    Expression handleBitwiseAndExpr()
    {
        Expression left = handleComparisonExpr(); // comparison
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_AND:
                    nextToken(); // &
                    Expression right = handleComparisonExpr(); // comparison
                    left = new BinaryOperatorExpression(BinaryOperatorType.BITWISE_AND, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }
    
    Expression handleComparisonExpr()
    {
        Expression left = handleShiftExpr(); // shift
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_LT:
                    nextToken(); // <
                    Expression right = handleShiftExpr(); // shift
                    left = new BinaryOperatorExpression(BinaryOperatorType.LT, left, right, position);
                    break;
                case Token.OP_LE:
                    nextToken(); // <=
                    Expression right = handleShiftExpr(); // shift
                    left = new BinaryOperatorExpression(BinaryOperatorType.LE, left, right, position);
                    break;
                case Token.OP_NE:
                    nextToken(); // <>
                    Expression right = handleShiftExpr(); // shift
                    left = new BinaryOperatorExpression(BinaryOperatorType.NE, left, right, position);
                    break;
                case Token.OP_GT:
                    nextToken(); // >
                    Expression right = handleShiftExpr(); // shift
                    left = new BinaryOperatorExpression(BinaryOperatorType.GT, left, right, position);
                    break;
                case Token.OP_GE:
                    nextToken(); // >=
                    Expression right = handleShiftExpr(); // shift
                    left = new BinaryOperatorExpression(BinaryOperatorType.GE, left, right, position);
                    break;
                case Token.OP_EQ:
                    nextToken(); // ==
                    Expression right = handleShiftExpr(); // shift
                    left = new BinaryOperatorExpression(BinaryOperatorType.EQ, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }
    
    Expression handleShiftExpr()
    {
        Expression left = handleAdditiveExpr(); // additive
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_SHL:
                    nextToken(); // <<
                    Expression right = handleAdditiveExpr(); // additive
                    left = new BinaryOperatorExpression(BinaryOperatorType.SHL, left, right, position);
                    break;
                case Token.OP_SHR:
                    nextToken(); // >>
                    Expression right = handleAdditiveExpr(); // additive
                    left = new BinaryOperatorExpression(BinaryOperatorType.SHR, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }
    
    Expression handleAdditiveExpr()
    {
        Expression left = handleMultiplicativeExpr(); // multiplicative
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_ADD:
                    nextToken(); // +
                    Expression right = handleMultiplicativeExpr(); // multiplicative
                    left = new BinaryOperatorExpression(BinaryOperatorType.ADD, left, right, position);
                    break;
                case Token.OP_SUB:
                    nextToken(); // -
                    Expression right = handleMultiplicativeExpr(); // multiplicative
                    left = new BinaryOperatorExpression(BinaryOperatorType.SUB, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }
    
    Expression handleMultiplicativeExpr()
    {
        Expression left = handleTerm(); // term
        while(true)
        {
            SourcePosition position = new SourcePosition(scanner.getPosition());
            switch(token)
            {
                case Token.OP_MUL:
                    nextToken(); // *
                    Expression right = handleTerm(); // term
                    left = new BinaryOperatorExpression(BinaryOperatorType.MUL, left, right, position);
                    break;
                case Token.OP_DIV:
                    nextToken(); // /
                    Expression right = handleTerm(); // term
                    left = new BinaryOperatorExpression(BinaryOperatorType.DIV, left, right, position);
                    break;
                case Token.OP_MOD:
                    nextToken(); // %
                    Expression right = handleTerm(); // term
                    left = new BinaryOperatorExpression(BinaryOperatorType.MOD, left, right, position);
                    break;
                default:
                    return left;
            }
        }
    }

    Expression handleTerm()
    {
        SourcePosition position = new SourcePosition(scanner.getPosition());
        switch(token)
        {
            case Token.INTEGER:
                Expression expr = new NumericExpression(std.conv.parse!uint(text), NumericType.INTEGER, position);
                nextToken(); // INTEGER
                return expr;
            case Token.HEXADECIMAL:
                Expression expr = new NumericExpression(std.conv.parse!uint(text, 16), NumericType.HEXADECIMAL, position);
                nextToken(); // HEXADECIMAL
                return expr;
            case Token.BINARY:
                Expression expr = new NumericExpression(std.conv.parse!uint(text, 2), NumericType.BINARY, position);
                nextToken(); // BINARY
                return expr;
            case Token.PUNC_LPAREN:
                nextToken(); // (
                Expression expr = handleExpr(); // expr 
                consume(Token.PUNC_RPAREN); // )
                return new UnaryOperatorExpression(UnaryOperatorType.NONE, expr, position);
            case Token.OP_LT:
                nextToken(); // <
                Expression expr = handleTerm(); // term
                return new UnaryOperatorExpression(UnaryOperatorType.BYTE_LOW, expr, position);
            case Token.OP_GT:
                nextToken(); // >
                Expression expr = handleTerm(); // term
                return new UnaryOperatorExpression(UnaryOperatorType.BYTE_HIGH, expr, position);
            case Token.PUNC_EXCLAIM:
                nextToken(); // !
                Expression expr = handleTerm(); // term
                return new UnaryOperatorExpression(UnaryOperatorType.LOGICAL_NOT, expr, position);
            case Token.IDENTIFIER:
                string[] pieces;
                
                if(checkIdentifier())
                {
                    pieces ~= text;
                }
                nextToken(); // IDENTIFIER
                
                // Check if we should match ('.' id)*
                bool more = token == Token.PUNC_DOT;
                while(more)
                {
                    nextToken(); // .
                    if(token == Token.IDENTIFIER)
                    {
                        if(checkIdentifier())
                        {
                            pieces ~= text;
                        }
                        nextToken(); // IDENTIFIER
                        
                        // Check if we should match ('.' id)*
                        more = token == Token.PUNC_DOT;
                    }
                    else
                    {
                        error("expected identifier after '.' in term, but got " ~ getVerboseTokenName(token, text) ~ " instead", scanner.getPosition());
                        more = false;
                    }
                }

                return new AttributeExpression(new Attribute(pieces, position), scanner.getPosition());
            default:
                error("expected expression term but got " ~ getVerboseTokenName(token, text) ~ " instead", position);
                nextToken();
                return null;
        }
    }
}