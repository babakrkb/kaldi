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
		     .replace("۱", "1")
		     .replace("۲", "2")
		     .replace("۳", "3")
       		     .replace("۴", "4")
		     .replace("۵", "5")
		     .replace("۶", "6")
		     .replace("۷", "7")
		     .replace("۸", "8")
		     .replace("۹", "9")
		     .replace("۰", "0")
		     .replace("‘", "'"))))))
