module nel.ast.while_statement;

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

class WhileStatement : Statement
{
    private:
        Statement trueBranch;
        BranchCondition condition;
        BlockStatement block;
        
    public:
        this(BranchCondition condition, Statement trueBranch, SourcePosition position)
        {
            super(StatementType.WHILE, position);
            this.trueBranch = trueBranch;
            this.condition = condition;
            condition.setNegated(!condition.isNegated()); // Negate for conditional branching to work right.
        }
        
        void aggregate()
        {
            Statement[] statements;
            // def $while:
            // goto $end_while when condition
            //   trueBranch
            //   go $while
            // def $end_while:
            statements ~= new LabelDeclaration("$while", getPosition());
            statements ~= new BranchStatement(BranchType.GOTO,
                new Argument(ArgumentType.DIRECT,
                    new AttributeExpression(
                        new Attribute(["$end_while"], getPosition()), getPosition()
                    ), getPosition()
                ), condition, getPosition()
            );
            statements ~= trueBranch;
            statements ~= new BranchStatement(BranchType.GOTO,
                new Argument(ArgumentType.DIRECT,
                    new AttributeExpression(
                        new Attribute(["$while"], getPosition()), getPosition()
                    ), getPosition()
                ), getPosition()
            );
            statements ~= new LabelDeclaration("$end_while", getPosition());
            
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