#!/bin/bash
. ./cmd.sh
. ./path.sh

# This script is originally from qatip project (http://qatsdemo.cloudapp.net/qatip/demo/)
# of Qatar Computing Research Institute (http://qcri.qa/)

# To be run from one directory above this script.
# Prepare the dict folder. 
# Creating lexicon.txt, phonemeset, nonsilence_phones.txt, extra_questions.txt and silence_phones.txt.

local=data/local
phoneme_text=
lexicon_text=

. ./utils/parse_options.sh || exit 1
if [ -d "$local" ]; then
  rm -r $local
fi


# cat final_lm  > all_text
# cat data/train/text >> all_text
# cat data/test/text | awk '{ for(i=2;i<=NF;i++) print $i;}' | sort -u | awk '{print "id " $1}' >> all_text

## Determine phoneme set
mkdir -p $local/lm
cat $phoneme_text | cut -d' ' -f2- | tr ' ' "\n" | \
                                     tr '+' '\\' | \
                                     tr '=' '\\' | \
                                     sed 's/\xA0/X/g' | \
                                     sed 's/\x00\xA0/X/g' | \
                                     sed 's/\xC2\xA0/X/g' | \
                                     sed 's/\s\+/ /g' | \
                                     sed 's/ \+$//' | \
                                     sed 's/^ \+$//' | \
                                     sort -u  > $local/lm/train.vocab
cat $local/lm/train.vocab | python3 local/make_latin_words.py > $local/words2latin
cat $phoneme_text | cut -d' ' -f2- | tr ' ' "\n" | \
                                     tr '+' '\\' | \
                                     tr '=' '\\' | \
                                     sed 's/\xA0/X/g' | \
                                     sed 's/\x00\xA0/X/g' | \
                                     sed 's/\xC2\xA0/X/g' | \
                                     sed 's/\s\+/ /g' | \
                                     sed 's/ \+$//' | \
                                     sed 's/^ \+$//' | \
                                     python3 local/transcript_to_latin.py $local/words2latin | cut -d' ' -f2- | tr ' ' "\n" | sort | uniq -c | awk '{if ($1 > 2 || length($2) == 3) print $2}' | fgrep -v '~A' > $local/phonemeset

## Lexicon and word/phoneme lists
mkdir -p $local/dict
cat $local/words2latin | python3 local/map_to_rareA.py $local/phonemeset | sort -u > $local/dict/lexicon.txt
echo "<unk> rareA" >> $local/dict/lexicon.txt
echo "!SIL sil" >> $local/dict/lexicon.txt

cat $local/phonemeset | fgrep -v '.A' | fgrep -v ',A' | fgrep -v 'conn' | fgrep -v 'sil' | sort > $local/dict/nonsilence_phones.txt

echo ',A' > $local/dict/silence_phones.txt
echo '.A' >> $local/dict/silence_phones.txt
echo 'conn' >> $local/dict/silence_phones.txt
echo 'rareA' >> $local/dict/silence_phones.txt
echo 'sil' >> $local/dict/silence_phones.txt
echo 'sil' > $local/dict/optional_silence.txt
# config folder
cat config/extra_questions.txt| python3 local/reduce_to_vocabulary.py $local/dict/nonsilence_phones.txt | sort -u | fgrep ' ' > $local/dict/extra_questions.txt

mv $local/dict/lexicon.txt $local/dict/prelexicon.txt
# # add ligatures
cat $local/dict/prelexicon.txt |  sed 's/\s\+la[BM]\{1\}\s\+conn\s\+a[meha]\{1\}E/ laLE/g' | python3 local/add_ligature_variants.py config/ligatures | sort -u > $local/dict/lexicon.txt
cat $local/dict/lexicon.txt | cut -d' ' -f2- | tr ' ' "\n" | sort -u > $local/phonemeset
cat $local/phonemeset | fgrep -v 'rare' | fgrep -v '.A' | fgrep -v ',A' | fgrep -v 'conn' | fgrep -v 'sil' | sort > $local/dict/nonsilence_phones.txt


## Final Lexicon
cat $lexicon_text | cut -d' ' -f2- | tr ' ' "\n" | tr ' ' "\n" | \
                                     tr '+' '\\' | \
                                     tr '=' '\\' | \
                                     sed 's/\xA0/X/g' | \
                                     sed 's/\x00\xA0/X/g' | \
                                     sed 's/\xC2\xA0/X/g' | \
                                     sed 's/\s\+/ /g' | \
                                     sed 's/ \+$//' | \
                                     sed 's/^ \+$//' | \
                                     sort -u > $local/lm/lex.vocab
cat $local/lm/lex.vocab | python3 local/make_latin_words.py > $local/lex2latin
cat $local/lex2latin | python3 local/map_to_rareA.py $local/phonemeset | sort -u > $local/dict/lexicon.txt
echo "<unk> rareA" >> $local/dict/lexicon.txt
echo "!SIL sil" >> $local/dict/lexicon.txt

mv $local/dict/lexicon.txt $local/dict/prelexicon.txt
cat $local/dict/prelexicon.txt | \
            sed 's/\s\+la[BM]\{1\}\s\+conn\s\+a[meha]\{1\}E/ laLE/g' | \
            python3 local/add_ligature_variants.py config/ligatures | \
            sort -u > $local/dict/lexicon.txt

