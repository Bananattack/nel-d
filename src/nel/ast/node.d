module nel.ast.node;

import nel.report;

class Node
{
    private:
        SourcePosition position;
        
    public:
        this(SourcePosition position)
        {
            // Make a copy of that position, so it doesn't get modified by any outside code.
            this.position = new SourcePosition(position);
        }
        
        SourcePosition getPosition()
        {
            return position;
        }
}