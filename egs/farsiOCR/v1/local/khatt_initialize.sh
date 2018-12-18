#!/bin/bash

source cmd.sh
source path.sh

# Fetch transcriptions, invert images
# Note: this train/test set separation does not make much sense. More reasonable would be: 
# test: UniqueLinesTest
# train: Everything else
# -> FixedLinesTest shouldn't be in test set because LM contains these sentences
# However, we keep it that way because QATIP uses another LM and we want to be comparable to (Hamdani et. al., 2013) who
# separated test and train in that way


mkdir -p data/normalized
for set in test train
do
 echo $set
  # rm tmp.flist
  # if [ "$set" = "train" ]
  # then
  #   echo "train"
  #   folders="UniqueTextLineImages/Train FixedTextLineImages/Train"
  # fi
  # if [ "$set" = "validate" ]
  # then
  #   echo "validate"
  #   folders="UniqueTextLineImages/Validate FixedTextLineImages/Validate"
  # fi
  # if [ "$set" = "test" ]
  # then
  #   echo "test"
  #   folders="UniqueTextLineImages/Test FixedTextLineImages/Test"
  # fi
  # for folder in $folders
  # do
  #   ls /export/b01/babak/KHATT/KHATT_v1.0/LineImages_v1.0/$folder/*.tif >> tmp.flist
  # done
  # $train_cmd JOB=1 ./log/$set.normalize.log /export/b01/babak/prepocressor-0.2.1/prepocressor -inputFile tmp.flist -outputPath "data/binaries.tmp/%base.png" -pipeline 'grayscale| threshold -type BINARY_INV,OTSU|normalize' -nThreads 8
  # mkdir -p data/binaries
  touch data/text.$set
  rm data/text.$set
  # for txtPath in $(cat tmp.flist | sed 's/LineImages_v1.0\/\([FUa-z]\+\)TextLineImages/GroundTruth_v1.0\/\1TextUnicodeTruthValues-v1.0/' | sed 's/.tif$/.txt/')
  # do
  #   if [ -f "$txtPath" ]
  #   then
  #     base=$(basename $txtPath '.txt')
  #     newId=$(echo $base | sed 's/_\(.*\)_/_\1-/' | local/convert-to-qatip-id.sh khatt)
  #     echo "$newId $(head -1 "$txtPath" | iconv -f 'cp1256' -t 'utf-8' | python3 local/remove_diacritics.py | python3 local/normalize_punctuation.py)" >> data/text.$set
  #     mv data/binaries.tmp/$base.png data/binaries/$newId.png
  #   fi
  # done
  for textPath in $(ls /export/b01/babak/farsi/$set/20/*.txt)
  do
    base=$(basename $textPath '.txt')
    newId=$(echo $base | sed 's/_\(.*\)_/_\1-/' | local/convert-to-qatip-id.sh fontt)
    echo "$newId $(cat $textPath | python3 local/remove_diacritics.py | python3 local/normalize_punctuation.py)" >> data/text.$set
    cp /export/b01/babak/farsi/$set/20/$base.png data/normalized/$newId.png
  done
done
# rm tmp.flist
# rm -r data/binaries.tmp
