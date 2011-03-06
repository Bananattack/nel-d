#!/bin/env python
import os
import PIL.Image

def writeCHR(w, h, data, f):
    for y in range(0, h, 8):
        for x in range(0, w, 8):
            # Copy low bits of each 8x8 chunk into the first 8x8 plane.
            for j in range(8):
                c = 0
                for i in range(8):
                    c = (c * 2) | (data[x + i, y + j] & 1)
                f.write(chr(c))
            # Copy high bits of each chunk into the second 8x8 plane.
            for j in range(8):
                c = 0
                for i in range(8):
                    c = (c * 2) | ((data[x + i, y + j] >> 1) & 1)
                f.write(chr(c))

if __name__ == '__main__':
    import sys
    
    def main():
        if len(sys.argv) > 1:
                for arg in range(1, len(sys.argv)):
                    filename = sys.argv[arg]
                    
                    try:
                        img = PIL.Image.open(filename)
                    except Exception as e:
                        exit('Failure attempting to load ' + filename)
                        
                    w, h = img.size
                    if w != 128 or h != 128:
                        exit('Image ' + filename + ' is not 128x128 pixels in size.')
                    if not img.palette:
                        exit('Image ' + filename + ' has no palette.')
                    data = img.load()
                    
                    output = ''
                    #for y in range(h):
                    #    for x in range(w):
                    #        if data[x, y] < 0 or data[x, y] >= 4:
                    #            exit('Image uses colors outside of the first 4 palette entries.')

                    try:            
                        f = open(os.path.splitext(filename)[0] + '.chr', 'wb')
                    except Exception as e:
                        exit('Failure attempting to write ' + os.path.splitext(filename)[0] + '.chr')
                    
                    writeCHR(w, h, data, f)
                    f.close()
                                
                print(sys.argv[0] + ': Done!')
        else:
            print('Usage: ' + sys.argv[0] + ' file [file...]')
            print('Converts files like foo.png into NES-friendly formats like foo.chr')
    main()