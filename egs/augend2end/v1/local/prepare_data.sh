#!/bin/bash

# To be run from one directory above this script.
# Creat text, utt2spk, spk2utt, images.scp, and feats.scp for test and train.

. ./cmd.sh
. ./path.sh

mkdir -p data
for set in 'train' 'validate' 'test'
do
  ## Clean up
  if [[ -f tmp.unsorted ]]
  then
    rm tmp.unsorted
  fi
  if [ -d "data/$set" ]; then
    rm -r data/$set
  fi

  ## Gather transcriptions
  mkdir data/$set
  cat data/text.$set | cut -d' ' -f1 | xargs -IBLA -n 1 ls data/normalized/BLA.png | xargs -IBLA -n 1 basename BLA '.png' | xargs -IBLA -n 1 egrep '^BLA ' data/text.$set >> tmp.unsorted
  cat tmp.unsorted | sort -k1 > tmp.sorted
  cat tmp.sorted | cut -d' ' -f1 > data/$set/uttids
  cat tmp.sorted | cut -d' ' -f2- | python3 local/remove_diacritics.py | python3 local/replace_arabic_punctuation.py | tr '+' '\\' | tr '=' '\\' | sed 's/\xA0/X/g' | sed 's/\x00\xA0/X/g' | sed 's/\xC2\xA0/X/g' | sed 's/\s\+/ /g' | sed 's/ \+$//' | sed 's/^ \+$//' | paste -d' ' data/$set/uttids - > data/$set/text
  rm tmp.unsorted tmp.sorted

  ## Image files
  cat data/$set/uttids | sed 's/^\([a-z]\+\)-/\1 /i' | awk '{print "data/normalized/"$1"-"$2".png"}' | xargs -n 1 realpath > data/$set/img.flist
  paste -d' ' data/$set/uttids data/$set/img.flist > data/$set/img.scp

  ## Speaker mappings
  cat data/$set/uttids | sed 's/^\([^_]\+\)_/\1 /' | awk '{if (NF < 2) print $1" "$1; else print $1"_"$2" "$1}' > data/$set/utt2spk
  utils/utt2spk_to_spk2utt.pl data/$set/utt2spk > data/$set/spk2utt

done
