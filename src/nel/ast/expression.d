module nel.ast.expression;

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
static import std.string;

import nel.report;
import nel.ast.node;
import nel.ast.attribute;
import nel.ast.definition;
import nel.ast.storage_type;
import nel.ast.constant_declaration;

private immutable uint MAX_VALUE = 65535;
private immutable uint EXPANSION_STACK_MAX = 16;

enum ExpressionType
{
    NUMERIC,
    ATTRIBUTE,
    UNARY_OPERATOR,
    BINARY_OPERATOR,
}

enum NumericType
{
    INTEGER,
    HEXADECIMAL,
    BINARY,
}

enum UnaryOperatorType
{
    NONE,           // Brackets. Return the operand directly.
    BYTE_LOW,       // < operator. Returns operand & 0xFF
    BYTE_HIGH,      // > operator. Returns (operand >> 8)
    LOGICAL_NOT,    // ! operator. Returns 0 if operand is non-zero, 1 if operand is zero.
}

enum BinaryOperatorType
{
    // In order of precedence levels (which will have already been taken care of by the parser):
    // * / %
    MUL,            // Multiplication 
    DIV,            // Floor Division 
    MOD,            // Modulo     
    // + -
    ADD,            // Addition 
    SUB,            // Subtraction 
    // << >>
    SHL,            // A logical shift left. 
    SHR,            // A logical shift right.
    // < <= <> > >= =
    LT,             // Less than comparison.
    LE,             // Less than or equal comparison.
    NE,             // Not equal comparison.
    GT,             // Greater than comparison.
    GE,             // Greater than or equal comparison.
    EQ,             // Equal comparison.
    // &
    BITWISE_AND,    // A bitwise AND operation. 
    // ^
    BITWISE_XOR,    // A bitwise XOR operation. 
    // |
    BITWISE_OR,     // A bitwise OR operation.
    // &&
    LOGICAL_AND,    // A logical AND operation.
    // ||
    LOGICAL_OR,     // A logical OR operation.
}

abstract class Expression : Node
{
    private:
        ExpressionType expressionType;
        bool folded;
        uint foldedValue;
        
    public:
        this(ExpressionType expressionType, SourcePosition position)
        {
            super(position);
            
            this.expressionType = expressionType;
            this.folded = false;
            this.foldedValue = 0xDEADFACE;
        }
        
        ExpressionType getExpressionType()
        {
            return expressionType;
        }
        
        uint getFoldedValue()
        {
            return foldedValue;
        }
        
    protected:
        abstract bool fold(bool mustFold, bool forbidUndefined, Definition[] expansionStack);
        
    public:
        bool fold(bool mustFold, bool forbidUndefined)
        {
            return fold(mustFold, forbidUndefined, []);
        }
        
        abstract string toString();
}

class NumericExpression : Expression
{
    private:
        NumericType numericType;
        
    public:
        this(uint value, NumericType numericType, SourcePosition position)
        {
            super(ExpressionType.NUMERIC, position);
            
            this.folded = true;
            this.numericType = numericType;
            this.foldedValue = value;
        }
        
        bool fold(bool mustFold, bool forbidUndefined, Definition[] expansionStack)
        {
            return folded;
        }
        
        string toString()
        {
            switch(numericType)
            {
                case NumericType.INTEGER:
                    return std.conv.to!string(foldedValue);
                case NumericType.HEXADECIMAL:
                    return "0x" ~ std.conv.to!string(foldedValue, 16);
                case NumericType.BINARY:
                    return "0b" ~ std.conv.to!string(foldedValue, 2);
                default:
                    return "";
            }
        }
}

class AttributeExpression : Expression
{
    private:
        Attribute attribute;
        
    public:
        this(Attribute attribute, SourcePosition position)
        {
            super(ExpressionType.ATTRIBUTE, position);
            
            this.attribute = attribute;
        }
        
        bool fold(bool mustFold, bool forbidUndefined, Definition[] expansionStack)
        {
            Definition def = attribute.resolve();
            if(def !is null)
            {
                switch(def.getDefinitionType())
                {
                    case DefinitionType.CONSTANT:
                        ConstantDefinition constant = cast(ConstantDefinition) def;
                        ConstantDeclaration decl = constant.getDeclaration();
                        Expression expression = decl.getExpression();
                        
                        expansionStack ~= constant;
                        if(expansionStack.length > EXPANSION_STACK_MAX)
                        {   
                            string message = std.string.format(
                                "too many constant expansions required (exceeded max depth %s). "
                                ~ "are there mutually-dependent constants?", EXPANSION_STACK_MAX
                            );
                            
                            foreach(i, entry; expansionStack)
                            {
                                message ~= std.string.newline ~ "    '" ~ entry.getName() ~ "' at " ~ entry.getPosition().toString();
                            }
                            error(message, getPosition(), true);
                        }
                        else
                        {
                            folded = expression.fold(mustFold, forbidUndefined, expansionStack);
                        }
                        expansionStack.length = expansionStack.length - 1; // Pop.
                        
                        // Value of constant is its folded expression value, plus its offset
                        foldedValue = expression.getFoldedValue() + decl.getExpressionOffset();
                        if(decl.getSize() == StorageType.BYTE && foldedValue > 255)
                        {
                            string message = std.string.format(
                                "%s '%s' is declared as 'byte'-sized, but has the value %s, which is outside of representable 8-bit range 0..255",
                                expression.getFoldedValue() <= 255 ? "enum constant" : "constant", attribute.getFullName(), foldedValue
                            );
                            error(message, getPosition());
                        }
                        else if(foldedValue > MAX_VALUE)
                        {
                            string message = std.string.format(
                                "%s '%s' has the value %s, which is outside of representable range 0..65535",
                                expression.getFoldedValue() <= MAX_VALUE ? "enum constant" : "constant", attribute.getFullName(), foldedValue
                            );
                            error(message, getPosition());
                        }
                        break;
                    case DefinitionType.VARIABLE:
                        VariableDefinition variable = cast(VariableDefinition) def;
                        foldedValue = variable.getOffset();
                        folded = true;
                        break;
                    case DefinitionType.LABEL:
                        LabelDefinition label = cast(LabelDefinition) def;
                        folded = label.isKnownOffset();
                        foldedValue = label.getOffset();
                        break;
                    case DefinitionType.PACKAGE:
                        string message = std.string.format(
                            "attempted to use package '%s' in an expression. packages have no values, use their members instead.", attribute.getFullName()
                        );
                        error(message, getPosition());
                        foldedValue = 0xFACEBEEF;
                        folded = false;
                        break;
                    default:
                        error("unexpected compilation error: unknown DefinitionType", getPosition());
                }
            }
            
            if(!def && forbidUndefined)
            {
                error("'" ~ attribute.getFullName() ~ "' is not defined anywhere.", getPosition());
            }
            else if(!folded && mustFold)
            {
                if(!def)
                {
                    error("expression '" ~ attribute.getFullName() ~ "' has an indeterminate value.", getPosition());
                }
                else
                {
                    error("expression '" ~ attribute.getFullName() ~ "' is defined, but has an indeterminate value.", getPosition());
                }
            }
            return folded;
        }
        
        string toString()
        {
            return attribute.getFullName();
        }
}

class UnaryOperatorExpression : Expression
{
    private:
        UnaryOperatorType unaryOperatorType;
        Expression operand;
        
    public:
        this(UnaryOperatorType unaryOperatorType, Expression operand, SourcePosition position)
        {
            super(ExpressionType.UNARY_OPERATOR, position);
            
            this.unaryOperatorType = unaryOperatorType;
            this.operand = operand;
        }
        
        UnaryOperatorType getUnaryOperatorType()
        {
            return unaryOperatorType;
        }
        
        Expression getOperand()
        {
            return operand;
        }
        
        bool fold(bool mustFold, bool forbidUndefined, Definition[] expansionStack)
        {
            folded = operand.fold(mustFold, forbidUndefined, expansionStack);
            if(!folded)
            {
                return false;
            }
            
            foldedValue = operand.getFoldedValue();
            switch(unaryOperatorType)
            {
                case UnaryOperatorType.NONE:
                    break;
                case UnaryOperatorType.BYTE_LOW:
                    foldedValue = foldedValue & 0xFF;
                    break;
                case UnaryOperatorType.BYTE_HIGH:
                    foldedValue = foldedValue >> 8;
                    break;
                case UnaryOperatorType.LOGICAL_NOT:
                    foldedValue = foldedValue != 0 ? 0 : 1;
                    break;
                default:
                    error("unexpected compilation error: unknown UnaryOperatorType", getPosition());
            }
            return folded;
        }
        
        string toString()
        {
            string op = operand !is null ? operand.toString() : "";
            switch(unaryOperatorType)
            {
                case UnaryOperatorType.NONE:
                    return "(" ~ op ~ ")";
                case UnaryOperatorType.BYTE_LOW:
                    return "<" ~ op;
                case UnaryOperatorType.BYTE_HIGH:
                    return ">" ~ op;
                case UnaryOperatorType.LOGICAL_NOT:
                    return "!" ~ op;
                default:
                    error("unexpected compilation error: unknown UnaryOperatorType", getPosition());
                    assert(0);
            }
        }
}

class BinaryOperatorExpression : Expression
{
    private:
        BinaryOperatorType binaryOperatorType;
        Expression left, right;
        
    public:
        this(BinaryOperatorType binaryOperatorType, Expression left, Expression right, SourcePosition position)
        {
            super(ExpressionType.BINARY_OPERATOR, position);
            
            this.binaryOperatorType = binaryOperatorType;
            this.left = left;
            this.right = right;
        }
        
        BinaryOperatorType getBinaryOperatorType()
        {
            return binaryOperatorType;
        }
        
        Expression getLeft()
        {
            return left;
        }
        
        Expression getRight()
        {
            return right;
        }
        
        bool fold(bool mustFold, bool forbidUndefined, Definition[] expansionStack)
        {
            bool lfolded = left.fold(mustFold, forbidUndefined, expansionStack);
            bool rfolded = false;
            
            // Fold now if not short-circuited.
            switch(binaryOperatorType)
            {
                case BinaryOperatorType.LOGICAL_AND:
                case BinaryOperatorType.LOGICAL_OR:
                    break;
                default:
                    rfolded = right.fold(mustFold, forbidUndefined, expansionStack);
                    if(!rfolded)
                    {
                        return false;
                    }
                    break;
            }
            if(!lfolded)
            {
                return false;
            }
            folded = true;
            
            uint ls = left.getFoldedValue();
            uint rs = right.getFoldedValue(); // rs is undefined if right isn't folded, so avoid using its value before then.
            switch(binaryOperatorType)
            {
                case BinaryOperatorType.MUL:
                    if(ls > MAX_VALUE / rs)
                    {
                        error("multiplication yields result which will overflow outside of 0..65535.", right.getPosition());
                        folded = false;
                    }
                    else
                    {
                        foldedValue = ls * rs;
                    }
                    break;
                case BinaryOperatorType.DIV:
                    if(rs == 0)
                    {
                        error("division by zero is undefined.", right.getPosition());
                        folded = false;
                    }
                    else
                    {
                        foldedValue = ls / rs;
                    }
                    break;
                case BinaryOperatorType.MOD:
                    if(rs == 0)
                    {
                        error("modulo by zero is undefined.", right.getPosition());
                        folded = false;
                    }
                    else
                    {
                        foldedValue = ls % rs;
                    }
                    break;
                case BinaryOperatorType.ADD:
                    if(ls + MAX_VALUE < rs)
                    {
                        error("addition yields result which will overflow outside of 0..65535.", right.getPosition());
                        folded = false;
                    }
                    else
                    {
                        foldedValue = ls + rs;
                    }
                    break;
                case BinaryOperatorType.SUB:
                    if(ls < rs)
                    {
                        error("subtraction yields result which will overflow outside of 0..65535.", right.getPosition());
                        folded = false;
                    }
                    else
                    {
                        foldedValue = ls - rs;
                    }
                    break;
                case BinaryOperatorType.SHL:
                    // If shifting more than N bits, or ls << rs > 2^N-1, then error.
                    if(rs > 16 || (rs > 0 && (ls & ~(1 << (16 - rs))) != 0))
                    {
                        error("logical shift left yields result which will overflow outside of 0..65535.", right.getPosition());
                        folded = false;
                    }
                    else
                    {
                        foldedValue = ls << rs;
                    }
                    break;
                case BinaryOperatorType.SHR:
                    foldedValue = ls >> rs;
                    break;
                case BinaryOperatorType.LT:
                    foldedValue = ls < rs ? 1 : 0;
                    break;
                case BinaryOperatorType.LE:
                    foldedValue = ls <= rs ? 1 : 0;
                    break;
                case BinaryOperatorType.NE:
                    foldedValue = ls != rs ? 1 : 0;
                    break;
                case BinaryOperatorType.GT:
                    foldedValue = ls > rs ? 1 : 0;
                    break;
                case BinaryOperatorType.GE:
                    foldedValue = ls >= rs ? 1 : 0;
                    break;
                case BinaryOperatorType.EQ:
                    foldedValue = ls == rs ? 1 : 0;
                    break;
                case BinaryOperatorType.BITWISE_AND:
                    foldedValue = ls & rs;
                    break;
                case BinaryOperatorType.BITWISE_XOR:
                    foldedValue = ls ^ rs;
                    break;
                case BinaryOperatorType.BITWISE_OR:
                    foldedValue = ls | rs;
                    break;
                case BinaryOperatorType.LOGICAL_AND:
                    // Short-circuiting. Don't evaluate right branch if left branch is zero.
                    if(ls == 0)
                    {
                        foldedValue = 0;
                    }
                    // Left is non-zero. We must evaluate the right branch.
                    else
                    {
                        rfolded = right.fold(mustFold, forbidUndefined, expansionStack);
                        if(!rfolded)
                        {   
                            folded = false;
                            return false;
                        }
                        rs = right.getFoldedValue();
                        // True if ls != 0 && rs != 0.
                        // False if ls != 0 && rs == 0.
                        foldedValue = rs != 0 ? 1 : 0;
                    }
                    break;
                case BinaryOperatorType.LOGICAL_OR:
                    // Short-circuiting. Don't evaluate right branch if left branch is non-zero.
                    if(ls != 0)
                    {
                        foldedValue = 1;
                    }
                    // Left is false. We must evaluate the right branch.
                    else
                    {
                        rfolded = right.fold(mustFold, forbidUndefined, expansionStack);
                        if(!rfolded)
                        {   
                            folded = false;
                            return false;
                        }
                        rs = right.getFoldedValue();
                        // False if ls == 0 && rs == 0.
                        // True if ls == 0 && rs != 0.
                        foldedValue = rs == 0 ? 0 : 1;
                    }
                    break;
                default:
                    error("unexpected compilation error: unknown BinaryOperatorType", getPosition());
            }
            return folded;
        }
        
        string toString()
        {
            string ls = left !is null ? left.toString() : "";
            string rs = right !is null ? right.toString() : "";
            switch(binaryOperatorType)
            {
                case BinaryOperatorType.MUL:
                    return ls ~ " * " ~ rs;
                case BinaryOperatorType.DIV:
                    return ls ~ " / " ~ rs;
                case BinaryOperatorType.MOD:
                    return ls ~ " % " ~ rs;
                case BinaryOperatorType.ADD:
                    return ls ~ " + " ~ rs;
                case BinaryOperatorType.SUB:
                    return ls ~ " - " ~ rs;
                case BinaryOperatorType.SHL:
                    return ls ~ " << " ~ rs;
                case BinaryOperatorType.SHR:
                    return ls ~ " >> " ~ rs;
                case BinaryOperatorType.LT:
                    return ls ~ " < " ~ rs;
                case BinaryOperatorType.LE:
                    return ls ~ " <= " ~ rs;
                case BinaryOperatorType.NE:
                    return ls ~ " <> " ~ rs;
                case BinaryOperatorType.GT:
                    return ls ~ " > " ~ rs;
                case BinaryOperatorType.GE:
                    return ls ~ " >= " ~ rs;
                case BinaryOperatorType.EQ:
                    return ls ~ " = " ~ rs;
                case BinaryOperatorType.BITWISE_AND:
                    return ls ~ " & " ~ rs;
                case BinaryOperatorType.BITWISE_XOR:
                    return ls ~ " ^ " ~ rs;
                case BinaryOperatorType.BITWISE_OR:
                    return ls ~ " | " ~ rs;
                case BinaryOperatorType.LOGICAL_AND:
                    return ls ~ " && " ~ rs;
                case BinaryOperatorType.LOGICAL_OR:
                    return ls ~ " || " ~ rs;
                default:
                    error("unexpected compilation error: unknown BinaryOperatorType", getPosition());
                    assert(0);
            }
        }
}
