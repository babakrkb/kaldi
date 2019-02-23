#!/bin/bash

stage=0
nj=8

# ienit_database points to the database path on the JHU grid.
# you can change this to your local directory of the dataset

. ./path.sh
. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

if [ $stage -le 0 ]; then
  # Initializing
  echo "Initializing"
  #local/khatt_initialize.sh
  local/farsi_initialize.sh
  # local/khatt_normalize.sh
  #cp -r data/binaries/A* data/normalized
  #$cmd JOB=1 ./log/python.log python local/augment.py
  ls data/preaug/*.png > tmp.flist 
  $train_cmd JOB=1 ./log/gray.log /export/b01/babak/prepocressor-0.2.1/prepocressor -inputFile tmp.flist -outputPath "data/normalized/%base.png" -pipeline 'grayscale' -nThreads 8
  rm -r tmp.flist
fi

if [ $stage -le 1 ]; then
  # data preparation
  echo "data preparation"

  # Determine test and train sets
  cat data/farsi.test > data/text.test
  cat data/farsi.train > data/text.train
  cat data/farsi.train | sed 's/A/B/g' >> data/text.train
  cat data/farsi.train | sed 's/A/C/g' >> data/text.train
  cat data/farsi.train | sed 's/A/D/g' >> data/text.train
  cat data/farsi.train | sed 's/A/E/g' >> data/text.train

  # cat data/khatt.test > data/text.test
  # cat data/khatt.train > data/text.train

  # data preparation 
  local/prepare_data.sh
fi

if [ $stage -le 0 ]; then
  # Making textes for dict and lang
  touch data/phoneme_text data/train_lex data/test_lex
  rm -r data/phoneme_text data/train_lex data/test_lex

  for set in test train
  do
    cat data/farsi.$set >> data/phoneme_text
    cat data/khatt.$set >> data/phoneme_text
  done

  for set in test train
  do
    cat data/farsi.$set >> data/train_lex
    cat data/khatt.$set >> data/train_lex
  done

  for set in test train
  do
    cat data/farsi.$set >> data/test_lex
  done

  local/prepare_dict.sh --local data/local_train --phoneme-text data/phoneme_text --lexicon-text data/train_lex
  local/prepare_dict.sh --local data/local_test --phoneme-text data/phoneme_text --lexicon-text data/test_lex

  utils/prepare_lang.sh --num-sil-states 3 --num-nonsil-states 4 --position-dependent-phones false data/local_train/dict "<unk>" data/lang/temp data/lang
  utils/prepare_lang.sh --num-sil-states 3 --num-nonsil-states 4 --position-dependent-phones false data/local_test/dict "<unk>" data/lang_test/temp data/lang_test
fi

if [ $stage -le 0 ]; then
  # LM preparation
  echo "LM preparation"
  cat final_lm | python3 local/remove_diacritics.py | python3 local/normalize_punctuation.py > data/farsi_big_lm
  cat data/test/text >> data/farsi_big_lm
  cat data/train/text >> data/farsi_big_lm
  # cat data/test/text | awk '{ for(i=2;i<=NF;i++) print $i;}' | sort -u | awk '{print "id " $1}' >> data/farsi_big_lm
  
  local/train_lms_srilm.sh --oov-symbol "<unk>" --train-text data/farsi_big_lm data data/lm_final
  utils/format_lm.sh data/lang data/lm_final/3gram.kn011.gz data/local_test/dict/lexicon.txt data/lang_test

fi

if [ $stage -le 4 ]; then
  echo "$0: Obtaining image groups. calling get_image2num_frames"
  echo "Date: $(date)."
  image/get_image2num_frames.py data/train  # This will be needed for the next command
  # The next command creates a "allowed_lengths.txt" file in data/train
  # which will be used by local/make_features.py to enforce the images to
  # have allowed lengths. The allowed lengths will be spaced by 10% difference in length.
  echo "$0: Obtaining image groups. calling get_allowed_lengths"
  echo "Date: $(date)."
  image/get_allowed_lengths.py --frame-subsampling-factor 4 10 data/train
fi

if [ $stage -le 5 ]; then
  for dataset in test train; do
    echo "$0: Extracting features and calling compute_cmvn_stats for dataset:  $dataset. "
    echo "Date: $(date)."
    local/extract_features.sh --nj $nj --cmd $cmd --feat-dim 40 data/$dataset
    steps/compute_cmvn_stats.sh data/$dataset || exit 1;
  done
  echo "$0: Fixing data directory for train dataset"
  echo "Date: $(date)."
  utils/fix_data_dir.sh data/train
fi

# if [ $stage -le 6 ]; then
#   echo "$0: Calling the flat-start chain recipe..."
#   echo "Date: $(date)."
#   local/chain/run_flatstart_cnn1a.sh --nj $nj --lang-test lang_test
# fi

if [ $stage -le 7 ]; then
  echo "$0: Aligning the training data using the e2e chain model..."
  echo "Date: $(date)."
  steps/nnet3/align.sh --nj $nj --cmd "$cmd" \
                       --use-gpu false \
                       --scale-opts '--transition-scale=1.0 --self-loop-scale=1.0 --acoustic-scale=1.0' \
                       data/train data/lang exp/chain/e2e_cnn_1a exp/chain/e2e_ali_train
fi

if [ $stage -le 8 ]; then
  echo "$0: Calling the transfer chain recipe..."
  echo "Date: $(date)."
  local/chain/run_khatt_farsi.sh 
fi


# if [ $stage -le 7 ]; then
#   echo "$0: Building a tree and training a regular chain model using the e2e alignments..."
#   echo "Date: $(date)."
#   local/chain/run_cnn_e2eali_1b.sh --nj $nj
# fi
