
-----------------------------------------------------
  nel
-----------------------------------------------------
  by Andrew Crowell / Overkill
  
  A low-level language for making homebrew NES games.
-----------------------------------------------------


Table of Contents
-----------------
* Introduction
* Compiling the Compiler
* The Manual
* The License
* Acknowledgements


Introduction
------------

nel is a project I started to make development for the NES "easier", by
diverting my time from making a game to working on a compiler for the 6502.
It aims to remove a lot of unnecessary formatting requirements on your source
code, and to unify certain mnemonics in the "official" 6502 assembly, with a
simplified syntax. It is a 3-pass compiler that generates machine code in .nes
/ iNES format at the end.

The language is not meant to provide many truly high-level concepts. It aims to
only to aid in the development of low-level coding, and to that effect, has no
"standard library", only built-in commands and language constructs that map
closely (often exactly) to single machine code instructions (with the exception
of `add` / `sub` / `neg` / `not` commands, which become multiple instructions).

Although I originally made this for my own interest, feel free to use it for
your NES homebrew projects.

The Compiler
------------

Usage: nel [... arg]
    where args can can be one of the following:
        input_filename
            The name of the nel source file to compile.
        -o output_filename 
           The name of the .nes rom file to generate.
           (defaults to input_filename + '.nes').
        -h or --help
            A usage message, similar to this.

For example, to compile "test.nel", you could simply type:
    nel test.nel
    
If the file successfully compiles, this will output a file named test.nes.
To actually write programs in this language, I recommend reading the manual.

The Manual
----------

The manual can be found at: https://github.com/Bananattack/nel-d/wiki

This provides better detailed descriptions of nel, the language reference,
and other fun things. Check it out!


The License
-----------

This program is released under an MIT license.


Copyright (C) 2011 by Andrew G. Crowell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


Acknowledgements
----------------

In no particular order:

* http://www.obelisk.demon.co.uk/6502/ - 6502 Introduction by Andrew Jacobs for
  extremely handy instruction charts and breakdown of how the addressing modes
  and other stuff works.
* http://www.6502.org/ - 6502.org for various ideas, and some nice articles.
* http://www.magicengine.com/mkit/ - MagicKit for NESASM, and eventually
  inspiration to not use NESASM and make my own language instead.
* http://nesdev.parodius.com/ - NESdev for many useful reads, ranging from old
  documents, to wiki pages, to interesting forum posts. This helped with NES
  development ideas, with learning the iNES format, and learning various 6502
  assembly.
* http://www.nintendoage.com/ - NintendoAge for their excellent "Nerdy Nights"
  tutorials on learning to program for the NES.
* Possibly more.
