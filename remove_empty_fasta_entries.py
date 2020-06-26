#!/usr/local/env python3

import sys

in_fasta = sys.argv[1]
out_fasta = in_fasta + '.clean'

with open(out_fasta, 'w') as ofh:
    with open(in_fasta, 'r') as ifh:
        header = ''
        seq_list = list()
        for line in ifh:
            line = line.rstrip()
            if line.startswith('>'):
                if seq_list:
                    # Write previous sequence to file
                    ofh.write('{}\n{}\n'.format(header, ''.join(seq_list)))

                    # Get header info of new sequence
                    header = line
                    seq_list = list()
                else:
                    header = line
            else:
                if line == '':
                    print('Sequence {} is empty'.format(header.replace('>', '')))
                    header = ''
                    seq_list = list()
                else:
                    seq_list.append(line)
        if header and seq_list:
            ofh.write('{}\n{}\n'.format(header, ''.join(seq_list)))
