#!/bin/bash
source cmd.sh
source path.sh

mv data/normalized data/preaug
mkdir -p data/pre_grayscale data/normalized

for set in test validate
do
    for filename in $(awk -F" " '{if ($1) print $1}' data/text.$set)
    do
        mv data/preaug/$filename.png data/normalized
    done
done

$cmd JOB=1 ./log/python.log python local/augment.py

for file in $(ls data/preaug/*.png)
do
    mv $file data/normalized
done

touch data/temp
rm data/temp
ls data/pre_grayscale/*.png > data/temp

$train_cmd JOB=1 ./log/gray.log /export/b01/babak/prepocressor-0.2.1/prepocressor -inputFile data/temp -outputPath "data/normalized/%base.png" -pipeline 'grayscale' -nThreads 8 

rm -r data/preaug

cp data/text.train data/text.train.temp
cat data/text.train.temp | sed 's/k/a/g' >> data/text.train
