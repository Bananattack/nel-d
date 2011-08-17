module nel.parse.token;

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

enum Token
{
    EMPTY,
    EOF,
    INVALID_CHAR,
    // Identifier. Keywords are also identifiers, but have reserved meaning determined later.
    IDENTIFIER,
    // Numeric constants.
    INTEGER,
    HEXADECIMAL,
    BINARY,
    // String literal.
    STRING,
    // Punctuation
    PUNC_COLON,
    PUNC_COMMA,
    PUNC_DOT,
    PUNC_LPAREN,
    PUNC_RPAREN,
    PUNC_LBRACKET,
    PUNC_RBRACKET,
    PUNC_LBRACE,
    PUNC_RBRACE,
    PUNC_AT,
    PUNC_HASH,
    PUNC_SEMI,
    PUNC_EXCLAIM,
    // Operator symbols.
    OP_ADD,
    OP_SUB,
    OP_MUL,
    OP_DIV,
    OP_MOD,
    OP_LT,
    OP_GT,
    OP_LE,
    OP_GE,
    OP_NE,
    OP_EQ,
    OP_SHL,
    OP_SHR,
    OP_AND,
    OP_XOR,
    OP_OR,
    OP_AND_AND,
    OP_OR_OR,
}

private string[] tokenNames = [
    "(???)",
    "end-of-file",
    "invalid character",
    // Identifier. Keywords are also identifiers, but have reserved meaning determined later.
    "identifier",
    // Numeric constants.
    "integer constant",
    "hexadecimal constant",
    "binary constant",
    // String literal.
    "string literal",
    // Punctuation
    "':'",
    "','",
    "'.'",
    "'('",
    "')'",
    "'['",
    "']'",
    "'{'",
    "'}'",
    "'@'",
    "'#'",
    "';'",
    "'!'",
    // Operator symbols.
    "'+'",
    "'-'",
    "'*'",
    "'/'",
    "'%'",
    "'<'",
    "'>'",
    "'<='",
    "'>='",
    "'<>'",
    "'='",
    "'<<'",
    "'>>'",
    "'&'",
    "'^'",
    "'|'",
    "'&&'",
    "'||'",
];

enum Keyword
{
    NONE,
    INES,
    DEF,
    LET,
    VAR,
    GOTO,
    WHEN,
    CALL,
    RETURN,
    RESUME,
    NOP,
    NOT,
    ROM,
    BANK,
    RAM,
    BYTE,
    WORD,
    BEGIN,
    PACKAGE,
    END,
    INCLUDE,
    EMBED,
    ENUM,
    IF,
    THEN,
    ELSE,
    ELSEIF,
    WHILE,
    DO,
    REPEAT,
    UNTIL
};

private Keyword[string] keywords;
private string[Keyword] keywordNames;

enum Builtin
{
    NONE,
    A,
    X,
    Y,
    S,
    P,
    ZERO,
    NEGATIVE,
    OVERFLOW,
    CARRY,
    DECIMAL,
    INTERRUPT
};

static this()
{
    keywords = [
        "ines": Keyword.INES,
        "def": Keyword.DEF,
        "let": Keyword.LET,
        "var": Keyword.VAR,
        "goto": Keyword.GOTO,
        "when": Keyword.WHEN,
        "call": Keyword.CALL,
        "return": Keyword.RETURN,
        "resume": Keyword.RESUME,
        "nop": Keyword.NOP,
        "not": Keyword.NOT,
        "rom": Keyword.ROM,
        "bank": Keyword.BANK,
        "ram": Keyword.RAM,
        "byte": Keyword.BYTE,
        "word": Keyword.WORD,
        "begin": Keyword.BEGIN,
        "package": Keyword.PACKAGE,
        "end": Keyword.END,
        "include": Keyword.INCLUDE,
        "embed": Keyword.EMBED,
        "enum": Keyword.ENUM,
        "if": Keyword.IF,
        "then": Keyword.THEN,
        "else": Keyword.ELSE,
        "elseif": Keyword.ELSEIF,
        "while": Keyword.WHILE,
        "do": Keyword.DO,
        "repeat": Keyword.REPEAT,
        "until": Keyword.UNTIL,
    ];
    
    foreach(name, keyword; keywords)
    {
        keywordNames[keyword] = name;
    }
}

string getSimpleTokenName(Token token)
{
    return tokenNames[token];
}

string getVerboseTokenName(Token token, string text)
{
    if(token == Token.IDENTIFIER)
    {
        Keyword keyword = findKeyword(text);
        if(keyword != Keyword.NONE)
        {
            return "keyword '" ~ text ~ "'";
        }
        else
        {
            return "identifier '" ~ text ~ "'";
        }
    }
    else
    {
        return getSimpleTokenName(token);
    }
}

string getKeywordName(Keyword keyword)
{
    return keywordNames[keyword];
}

Keyword findKeyword(string text)
{
    Keyword* match = text in keywords;
    return match is null ? Keyword.NONE : *match;
}