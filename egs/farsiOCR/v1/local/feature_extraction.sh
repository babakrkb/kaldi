source ./path.sh 
source ./cmd.sh

mkdir -p data/feats
for set in 'test'
do
  $train_cmd JOB=1 ./log/raw.log /export/b01/babak/prepocressor-0.2.1/prepocressor -inputFile data/$set/img.flist -nThreads 1 -outputPath 'no' -pipeline "grayscale|convertToFloat|normalize -newMax 1|featExtract -extractors raw -winWidth 1 -winShift 1 -kaldiFile data/feats/feats_$set.ark,t |devNull"
done