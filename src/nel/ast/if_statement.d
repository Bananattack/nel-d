module nel.ast.if_statement;

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
import nel.ast.rom;
import nel.ast.node;
import nel.ast.argument;
import nel.ast.attribute;
import nel.ast.statement;
import nel.ast.expression;
import nel.ast.block_statement;
import nel.ast.branch_statement;
import nel.ast.label_declaration;

enum IfType
{
    STATIC,
    RUNTIME,
}

abstract class IfStatement : Statement
{
    private:
        IfType ifType;
        Statement trueBranch;
        Statement falseBranch;
        
    public:
        this(IfType ifType, Statement trueBranch, SourcePosition position)
        {
            super(StatementType.IF, position);
            this.ifType = ifType;
            this.trueBranch = trueBranch;
        }
        
        IfType getIfType()
        {
            return ifType;
        }
        
        Statement getTrueBranch()
        {
            return trueBranch;
        }
        
        Statement getFalseBranch()
        {
            return falseBranch;
        }
        
        void setFalseBranch(Statement falseBranch)
        {
            this.falseBranch = falseBranch;
        }
}

class StaticIfStatement : IfStatement
{
    private:
        Expression expression;
        
    public:
        this(Expression expression, Statement trueBranch, SourcePosition position)
        {
            super(IfType.STATIC, trueBranch, position);
            this.expression = expression;
        }
        
        void aggregate()
        {
            if(!expression.fold(true, false))
            {
                error("if statement has a conditional expression which could not be resolved at compile-time.", getPosition());
                return;
            }
            if(expression.getFoldedValue() != 0)
            {
                trueBranch.aggregate();
            }
            else if(falseBranch !is null)
            {
                falseBranch.aggregate();
            }
        }
        
        void validate()
        {
            if(expression.getFoldedValue() != 0)
            {
                trueBranch.validate();
            }
            else if(falseBranch !is null)
            {
                falseBranch.validate();
            }
        }
        
        void generate()
        {
            if(expression.getFoldedValue() != 0)
            {
                trueBranch.generate();
            }
            else if(falseBranch !is null)
            {
                falseBranch.generate();
            }
        }
}

class RuntimeIfStatement : IfStatement
{
    private:
        BranchCondition condition;
        BlockStatement block;
        
    public:
        this(BranchCondition condition, Statement trueBranch, SourcePosition position)
        {
            super(IfType.RUNTIME, trueBranch, position);
            this.condition = condition;
            condition.setNegated(!condition.isNegated()); // Negate for conditional branching to work right.
        }
        
        void aggregate()
        {
            Statement[] statements;
            if(falseBranch is null)
            {
                // goto $end_if when condition
                //   trueBranch
                // def $end_if:
                statements ~= new BranchStatement(BranchType.GOTO,
                    new Argument(ArgumentType.DIRECT,
                        new AttributeExpression(
                            new Attribute(["$end_if"], getPosition()), getPosition()
                        ), getPosition()
                    ), condition, getPosition()
                );
                statements ~= trueBranch;
                statements ~= new LabelDeclaration("$end_if", getPosition());
            }
            else
            {
                // goto $else when condition
                //   trueBranch
                //   goto $end_if
                // def $else:
                //   falseBranch
                // def $end_if:
                statements ~= new BranchStatement(BranchType.GOTO,
                    new Argument(ArgumentType.DIRECT,
                        new AttributeExpression(
                            new Attribute(["$else"], getPosition()), getPosition()
                        ), getPosition()
                    ), condition, getPosition()
                );
                statements ~= trueBranch;
                statements ~= new BranchStatement(BranchType.GOTO,
                    new Argument(ArgumentType.DIRECT,
                        new AttributeExpression(
                            new Attribute(["$end_if"], getPosition()), getPosition()
                        ), getPosition()
                    ), getPosition()
                );
                statements ~= new LabelDeclaration("$else", getPosition());
                statements ~= falseBranch;
                statements ~= new LabelDeclaration("$end_if", getPosition());
            }
            
            block = new BlockStatement(BlockType.SCOPE, statements, getPosition());
            block.aggregate();
        }
        
        void validate()
        {
            block.validate();
        }
        
        void generate()
        {
            block.generate();
        }
}