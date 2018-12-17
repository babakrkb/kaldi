#!/bin/bash

source cmd.sh
source path.sh

mkdir -p data/normalized
for set in 'validate'
do
  touch data/text.$set
  rm data/text.$set
  for textPath in $(ls /export/b01/babak/data/$set/*.txt)
  do
   base=$(basename $textPath '.txt')
   newId=$(echo $base | sed 's/_\(.*\)_/_\1-/' | local/convert-to-qatip-id.sh fonts)
   echo "$newId $(cat $textPath | python3 local/remove_diacritics.py | python3 local/normalize_punctuation.py)" >> data/text.$set
    # cp /export/b01/babak/data/$set/$base.png data/normalized/$newId.png
  done
  mkdir data/$set
  cat data/text.$set >> tmp.unsorted
  cat tmp.unsorted | sort -k1 > tmp.sorted
  cat tmp.sorted | cut -d' ' -f1 > data/$set/uttids
  cat tmp.sorted | cut -d' ' -f2- | python3 local/remove_diacritics.py | python3 local/replace_arabic_punctuation.py | tr '+' '\\' | tr '=' '\\' | sed 's/\xA0/X/g' | sed 's/\x00\xA0/X/g' | sed 's/\xC2\xA0/X/g' | sed 's/\s\+/ /g' | sed 's/ \+$//' | sed 's/^ \+$//' | paste -d' ' data/$set/uttids - > data/$set/text
  rm tmp.unsorted tmp.sorted
done

## Determine phoneme set
mkdir -p data/local/lm
cat data/validate/text | cut -d' ' -f2- | tr ' ' "\n" | sort -u > data/local/lm/validate.vocab
cat data/local/lm/validate.vocab | python3 local/make_latin_words.py > data/validate/words2latin
cat data/validate/text | cut -d' ' -f2- | python3 local/transcript_to_latin.py data/validate/words2latin | cut -d' ' -f2- | tr ' ' "\n" | sort | uniq -c | awk '{if ($1 > 0 || length($2) == 3) print $2}' | fgrep -v '~A' > data/local/phonemeset

## Lexicon and word/phoneme lists
mkdir -p data/lang/
mkdir -p data/local/dict
echo '<unk>' > data/lang/oov.txt
cat data/validate/words2latin | python3 local/map_to_rareA.py data/local/phonemeset > data/local/dict/lexicon.txt
echo "<unk> rareA" >> data/local/dict/lexicon.txt
echo "!SIL sil" >> data/local/dict/lexicon.txt

cat data/local/phonemeset | fgrep -v '.A' | fgrep -v ',A' | fgrep -v 'conn' | fgrep -v 'sil' | sort > data/local/dict/nonsilence_phones.txt

echo ',A' > data/local/dict/silence_phones.txt
echo '.A' >> data/local/dict/silence_phones.txt
echo 'conn' >> data/local/dict/silence_phones.txt
echo 'rareA' >> data/local/dict/silence_phones.txt
echo 'sil' >> data/local/dict/silence_phones.txt
echo 'sil' > data/local/dict/optional_silence.txt
# config folder
cat config/extra_questions.txt| python3 local/reduce_to_vocabulary.py data/local/dict/nonsilence_phones.txt | sort -u | fgrep ' ' > data/local/dict/extra_questions.txt

mv data/local/dict/lexicon.txt data/local/dict/prelexicon.txt
# # add ligatures
cat data/local/dict/prelexicon.txt |  sed 's/\s\+la[BM]\{1\}\s\+conn\s\+a[meha]\{1\}E/ laLE/g' | python3 local/add_ligature_variants.py config/ligatures > data/local/dict/lexicon.txt
cat data/local/dict/lexicon.txt| cut -d' ' -f2- | tr ' ' "\n" | sort -u > data/local/phonemeset
cat data/local/phonemeset | fgrep -v 'rare' | fgrep -v '.A' | fgrep -v ',A' | fgrep -v 'conn' | fgrep -v 'sil' | sort > data/local/dict/nonsilence_phones.txt


