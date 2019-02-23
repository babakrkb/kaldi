source cmd.sh
source path.sh

touch tmp.flist
rm tmp.flist


# for set in train test
# do
#   ls /export/b01/babak/farsihwr/$set/*.jpg >> tmp.flist
# done

# $train_cmd JOB=1 ./log/$set.normalize.log /export/b01/babak/prepocressor-0.2.1/prepocressor -inputFile tmp.flist -outputPath "data/binaries/%base.png" -pipeline 'grayscale| threshold -type BINARY_INV,OTSU|normalize' -nThreads 8


for set in train test
do
  touch data/farsi.$set
  rm data/farsi.$set
  for item in $(ls /export/b01/babak/farsihwr/$set/*.txt)
  do
     base=$(basename $item '.txt')
     echo "$base $(cat $item | python3 local/remove_diacritics.py | python3 local/normalize_punctuation.py)" >> data/farsi.$set
  done
done
