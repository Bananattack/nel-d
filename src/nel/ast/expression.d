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

import nel.report;
import nel.ast.node;
import nel.ast.attribute;
import nel.ast.definition;

private immutable uint MAX_VALUE = 65535;
private immutable uint EXPANSION_STACK_MAX = 16;

enum ExpressionType
{
    NUMERIC,
    ATTRIBUTE,
    OPERATOR,
}

enum OperatorType
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
    // &
    AND,            // A bitwise AND operation. 
    // ^
    XOR,            // A bitwise XOR operation. 
    // |
    OR              // A bitwise OR operation. 
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
}

class NumericExpression : Expression
{        
    public:
        this(uint value, SourcePosition position)
        {
            super(ExpressionType.NUMERIC, position);
            
            this.folded = true;
            this.foldedValue = value;
        }
        
        bool fold(bool mustFold, bool forbidUndefined, Definition[] expansionStack)
        {
            return folded;
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
                        Expression expression = constant.getDeclaration().getExpression();
                        
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
                        
                        foldedValue = expression.getFoldedValue();
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
}

class OperatorExpression : Expression
{
    private:
        OperatorType operatorType;
        Expression left, right;
        
    public:
        this(OperatorType operatorType, Expression left, Expression right, SourcePosition position)
        {
            super(ExpressionType.OPERATOR, position);
            
            this.operatorType = operatorType;
            this.left = left;
            this.right = right;
        }
        
        OperatorType getOperatorType()
        {
            return operatorType;
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
            bool lfolded = left.fold(mustFold, forbidUndefined);
            bool rfolded = right.fold(mustFold, forbidUndefined);
            
            if(!lfolded || !rfolded)
            {
                return false;
            }
            folded = true;
            
            uint ls = left.getFoldedValue();
            uint rs = right.getFoldedValue();
            switch(operatorType)
            {
                case OperatorType.MUL:
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
                case OperatorType.DIV:
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
                case OperatorType.MOD:
                    if(rs == 0)
                    {
                        error("modulo by zero is undefined.", right.getPosition());
                        folded = false;
                    }
                    else
                    {
                        foldedValue = ls / rs;
                    }
                    break;
                case OperatorType.ADD:
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
                case OperatorType.SUB:
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
                case OperatorType.SHL:
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
                case OperatorType.SHR:
                    foldedValue = ls >> rs;
                    break;
                case OperatorType.AND:
                    foldedValue = ls & rs;
                    break;
                case OperatorType.XOR:
                    foldedValue = ls ^ rs;
                    break;
                case OperatorType.OR:
                    foldedValue = ls | rs;
                    break;
            }
            return folded;
        }
}