import re
import sys, io

in_stream = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
out_stream = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

for line in in_stream:
    out_stream.write(
      re.sub(r' +', r' ',
      re.sub(r'^ +', r'',
      re.sub(r' +$', r'',
      re.sub(r'([.,"()\[\];:?1+/_\'-]+)', r' \1 ', line
		     .replace(" ", " ")
		     .replace("×", "x")
		     .replace("،", ",")
		     .replace("؛", ":")
		     .replace("؟", "?")
		     .replace("ـ", "_")   
		     .replace("–", "-")
		     .replace("‘", "'"))))))
