module nel.parse.scanner;

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

import nel.report;
import nel.parse.token;

enum State
{
    START,
    STRING,
    STRING_ESCAPE,
    LEADING_ZERO,
    INT_DIGITS,
    HEX_DIGITS,
    BIN_DIGITS,
    IDENTIFIER,
    SLASH,
    SLASH_SLASH_COMMENT,
    SLASH_STAR_COMMENT,
    SLASH_STAR_COMMENT_STAR,
    LT,
    GT,
    AMPERSAND,
    PIPE,
}

class Scanner
{
    private:
        char terminator;
        uint position;
        uint line;
        uint commentLine;
        char[] buffer;
        string text;
        string lastText;
        State state;
        std.stdio.File file;
        SourcePosition sourcePosition;
        
    public:
        this(std.stdio.File file, string filename)
        {
            this.file = file;
            sourcePosition = new SourcePosition(new SourceFile(filename));
        }
        
        void flushText()
        {
            lastText = text;
            text = "";
        }
        
        string getLastText()
        {
            string lastText = this.lastText;
            this.lastText = "";
            return lastText;
        }
        
        SourcePosition getPosition()
        {
            return sourcePosition;
        }
        
        Token next()
        {
            do
            {
                while(position < buffer.length)
                {
                    char c = buffer[position];
                    switch(state)
                    {
                        case State.START:
                            switch(c)
                            {
                                case '0':
                                    state = State.LEADING_ZERO;
                                    text ~= c;
                                    break;
                                case '1': .. case '9':
                                    state = State.INT_DIGITS;
                                    text ~= c;
                                    break;
                                case '_':
                                case 'a': .. case 'z':
                                case 'A': .. case 'Z':
                                    state = State.IDENTIFIER;
                                    text ~= c;
                                    break;
                                case '\'':
                                case '\"':
                                    terminator = c;
                                    state = State.STRING;
                                    break;
                                // Ignore whitespace (lines are tracked already by readln)
                                case '\t':
                                case ' ':
                                case '\r':
                                case '\n':
                                    break;
                                case '@': position++; return Token.PUNC_AT;
                                case '#': position++; return Token.PUNC_HASH;
                                case '=': position++; return Token.OP_EQ;
                                case '.': position++; return Token.PUNC_DOT;
                                case ',': position++; return Token.PUNC_COMMA;
                                case ':': position++; return Token.PUNC_COLON;
                                case '(': position++; return Token.PUNC_LPAREN;
                                case ')': position++; return Token.PUNC_RPAREN;
                                case '[': position++; return Token.PUNC_LBRACKET;
                                case ']': position++; return Token.PUNC_RBRACKET;
                                case '{': position++; return Token.PUNC_LBRACE;
                                case '}': position++; return Token.PUNC_RBRACE;
                                case ';': position++; return Token.PUNC_SEMI;
                                case '!': position++; return Token.PUNC_EXCLAIM;
                                case '+': position++; return Token.OP_ADD;
                                case '-': position++; return Token.OP_SUB;
                                case '*': position++; return Token.OP_MUL;
                                case '/':
                                    state = State.SLASH;
                                    break;
                                case '%': position++; return Token.OP_MOD;
                                case '^': position++; return Token.OP_XOR;
                                case '&':
                                    state = State.AMPERSAND;
                                    break;
                                case '|':
                                    state = State.PIPE;
                                    break;
                                case '<':
                                    state = State.LT;
                                    break;
                                case '>':
                                    state = State.GT;
                                    break;
                                default:
                                    error(std.string.format("unrecognized character %s found.", c), sourcePosition);
                            }
                            break;
                        case State.IDENTIFIER:
                            switch(c)
                            {
                                case '0': .. case '9':
                                case 'a': .. case 'z':
                                case 'A': .. case 'Z':
                                case '_':
                                    text ~= c;
                                    break;
                                default:
                                    state = State.START;
                                    flushText();
                                    return Token.IDENTIFIER;
                            }
                            break;
                        case State.STRING:
                            switch(c)
                            {
                                case '\"':
                                case '\'':
                                    if(c == terminator)
                                    {
                                        state = State.START;
                                        position++;
                                        flushText();
                                        return Token.STRING;
                                    }
                                    else
                                    {
                                        text ~= c;
                                    }
                                    break;
                                case '\\':
                                    state = State.STRING_ESCAPE;
                                    break;
                                default:
                                    text ~= c;
                                    break;
                            }
                            break;
                        case State.STRING_ESCAPE:
                            state = State.STRING;
                            switch(c)
                            {
                                case '\"':
                                case '\'':
                                case '\\':
                                    text ~= c;
                                    break;
                                case 't':
                                    text ~= '\t';
                                    break;
                                case 'r':
                                    text ~= '\r';
                                    break;
                                case 'n':
                                    text ~= '\n';
                                    break;
                                case 'f':
                                    text ~= '\f';
                                    break;
                                case 'b':
                                    text ~= '\b';
                                    break;
                                case 'a':
                                    text ~= '\a';
                                    break;
                                case '0':
                                    text ~= '\0';
                                    break;
                                default:
                                    error(std.string.format("invalid escape sequence \\%s in string literal", c), sourcePosition);
                                    break;
                            }
                            break;
                        case State.LEADING_ZERO:
                            switch(c)
                            {
                                case '0': .. case '9':
                                    state = State.INT_DIGITS;
                                    text ~= c;
                                    break;
                                case 'x':
                                    state = State.HEX_DIGITS;
                                    break;
                                case 'b':
                                    state = State.BIN_DIGITS;
                                    break;
                                default:
                                    state = State.START;
                                    flushText();
                                    return Token.INTEGER;
                            }                            
                            break;
                        case State.INT_DIGITS:
                            switch(c)
                            {
                                case '0': .. case '9':
                                    text ~= c;
                                    break;
                                default:
                                    state = State.START;
                                    flushText();
                                    return Token.INTEGER;
                            }
                            break;
                        case State.HEX_DIGITS:
                            switch(c)
                            {
                                case '0': .. case '9':
                                case 'a': .. case 'f':
                                case 'A': .. case 'F':
                                    text ~= c;
                                    break;
                                default:
                                    state = State.START;
                                    flushText();
                                    return Token.HEXADECIMAL;
                            }
                            break;
                        case State.BIN_DIGITS:
                            switch(c)
                            {
                                case '0': .. case '1':
                                    text ~= c;
                                    break;
                                default:
                                    state = State.START;
                                    flushText();
                                    return Token.BINARY;
                            }
                            break;
                        case State.SLASH:
                            switch(c)
                            {
                                case '/':
                                    state = State.SLASH_SLASH_COMMENT;
                                    break;
                                case '*':
                                    state = State.SLASH_STAR_COMMENT;
                                    commentLine = line;
                                    break;
                                default:
                                    state = State.START;
                                    return Token.OP_DIV;
                            }
                            break;
                        case State.SLASH_SLASH_COMMENT:
                            // Ignore input (end-of-line handling done elsewhere).
                            break;
                        case State.SLASH_STAR_COMMENT:
                            // Handle stars specially, ignore all else.
                            if(c == '*')
                            {
                                state = State.SLASH_STAR_COMMENT_STAR;
                            }
                            break;
                        case State.SLASH_STAR_COMMENT_STAR:
                            // If we find a /, this closes the comment.
                            if(c == '/')
                            {
                                state = State.START;
                            }
                            // False alarm, ignore.
                            else
                            {
                                state = State.SLASH_STAR_COMMENT;
                            }
                            break;
                        case State.LT:
                            state = State.START;
                            if(c == '<')
                            {
                                position++;
                                return Token.OP_SHL;
                            }
                            else if(c == '>')
                            {
                                position++;
                                return Token.OP_NE;
                            }
                            else if(c == '=')
                            {
                                position++;
                                return Token.OP_LE;
                            }
                            else
                            {
                                return Token.OP_LT;
                            }
                            break;
                        case State.GT:
                            state = State.START;
                            if(c == '>')
                            {
                                position++;
                                return Token.OP_SHR;
                            }
                            else if(c == '=')
                            {
                                position++;
                                return Token.OP_GE;
                            }
                            else
                            {
                                return Token.OP_GT;
                            }
                            break;
                        case State.AMPERSAND:
                            state = State.START;
                            if(c == '&')
                            {
                                position++;
                                return Token.OP_AND_AND;
                            }
                            else
                            {
                                return Token.OP_AND;
                            }
                            break;
                        case State.PIPE:
                            state = State.START;
                            if(c == '|')
                            {
                                position++;
                                return Token.OP_OR_OR;
                            }
                            else
                            {
                                return Token.OP_OR;
                            }
                            break;
                        default:
                            error("unexpected compilation error", sourcePosition);

                    }
                    // If we didn't return yet, increment position.
                    // This has the effect of letting delimiter characters be read twice
                    // (once to know a token ended, once to start the next token).
                    position++;
                }
                
                if(file.isOpen() && file.readln(buffer))
                {   
                    // Special handling in states for end-of-line.
                    switch(state)
                    {
                        case State.SLASH_SLASH_COMMENT:
                            state = State.START;
                            break;
                        case State.STRING:
                            error(std.string.format("expected closing quote %s, but got end-of-line", terminator), sourcePosition);
                            state = State.START;
                            break;
                        case State.STRING_ESCAPE:
                            error("expected string escape sequence, but got end-of-line", sourcePosition);
                            state = State.START;
                            break;
                        default:
                            break;
                    }
                    
                    position = 0;
                    line++;
                    sourcePosition.incrementLine();
                }
                else
                {
                    switch(state)
                    {
                        case State.IDENTIFIER:
                            // end-of-file doesn't cause identifier to become invalid, return
                            state = State.START;
                            flushText();
                            return Token.IDENTIFIER;
                        case State.LEADING_ZERO:
                        case State.INT_DIGITS:
                            state = State.START;
                            flushText();
                            return Token.INTEGER;
                        case State.HEX_DIGITS:
                            state = State.START;
                            flushText();
                            return Token.HEXADECIMAL;
                        case State.BIN_DIGITS:
                            state = State.START;
                            flushText();
                            return Token.BINARY;
                        case State.STRING:
                            error(std.string.format("expected closing quote %s, but got end-of-file", terminator), sourcePosition);
                            state = State.START;
                            break;
                        case State.STRING_ESCAPE:
                            error("expected string escape sequence, but got end-of-file", sourcePosition);
                            state = State.START;
                            break;
                        case State.SLASH_STAR_COMMENT:
                            error(std.string.format("expected */ to close /* comment starting on line %d, but got end-of-file", commentLine), sourcePosition);
                            break;
                        default:
                            break;
                    }
                    return Token.EOF;
                }
            } while(1);
            
            return Token.EOF;
        }
}

/*void main()
{
    string filename = "test.nel";
    Scanner scanner = new Scanner(File(filename, "rb"), filename);
    
    while(true)
    {
        Token token = scanner.next();
        writefln("token %d: %s", cast(int) token, scanner.getLastText());
        if(token == Token.EOF)
        {
            break;
        }
    }
}*/
