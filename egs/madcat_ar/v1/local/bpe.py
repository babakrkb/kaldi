#!/usr/bin/env python
# -*- coding: utf-8 -*-


import os,sys,inspect
currentdir = os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))
parentdir = os.path.dirname(currentdir)
sys.path.insert(0,parentdir)

import learn_bpe
from apply_bpe import BPE
import codecs, io

#infile = codecs.open(os.path.join(currentdir,'..','data','train','pre_text'), encoding='utf-8')
# infile = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
#outfile = codecs.open(os.path.join(currentdir,'..','data','train','bpe.out'), 'w', encoding='utf-8')
#learn_bpe.main(infile, outfile, 700)
#infile.close()
#outfile.close()

with codecs.open(os.path.join(currentdir,'..','data','train','bpe.out'), encoding='utf-8') as bpefile:
    bpe = BPE(bpefile)

infile = codecs.open(os.path.join(currentdir,'..','data','dev','pre_text'), encoding='utf-8')
output = codecs.open(os.path.join(currentdir,'..','data','dev','text_bpe'), 'w', encoding='utf-8')
# output = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

for line in infile:
    out = bpe.process_line(line)
    output.write(out)

