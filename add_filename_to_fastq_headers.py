#/usr/local/env python3

import sys
import gzip
import os

f = sys.argv[1]

output_file = f + '.renamed'

with gzip.open(output_file, 'wb') as ofh:
    with gzip.open(f, 'rt') as ifh:
        counter = 0
        bn = os.path.basename(f).split('.')[0]
        for line in ifh:
            counter += 1
            if counter == 1:
                line = line.replace('@', '')
                new_header = '@' + bn + "_" + line
                ofh.write(new_header.encode('utf-8'))
            else:
                ofh.write(line.encode('utf-8'))
            if counter == 4:
                counter = 0
