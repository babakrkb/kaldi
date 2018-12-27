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
  local/khatt_initialize.sh
  local/khatt_normalize.sh
fi

if [ $stage -le 1 ]; then
  # data preparation
  echo "data preparation"
  local/prepare_data.sh
  local/prepare_dict.sh
  utils/prepare_lang.sh --num-sil-states 3 --num-nonsil-states 4 --position-dependent-phones false data/local/dict "<unk>" data/local/lang data/lang
fi

if [ $stage -le 2 ]; then
  # LM preparation
  echo "LM preparation"
  cat data/train/text | sed '/^a/ d' > data/train.lm
  local/prepare_lm.sh --ngram 3 data/train.lm data/lang
fi

if [ $stage -le 3 ]; then
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

if [ $stage -le 4 ]; then
  for dataset in test validate train; do
    echo "$0: Extracting features and calling compute_cmvn_stats for dataset:  $dataset. "
    echo "Date: $(date)."
    local/extract_features.sh --nj $nj --cmd $cmd --feat-dim 40 data/$dataset
    steps/compute_cmvn_stats.sh data/$dataset || exit 1;
  done
  echo "$0: Fixing data directory for train dataset"
  echo "Date: $(date)."
  utils/fix_data_dir.sh data/train
fi

if [ $stage -le 5 ]; then
  echo "$0: Calling the flat-start chain recipe..."
  echo "Date: $(date)."
  local/chain/run_flatstart_cnn1a.sh --nj $nj
fi

if [ $stage -le 6 ]; then
  echo "$0: Aligning the training data using the e2e chain model..."
  echo "Date: $(date)."
  steps/nnet3/align.sh --nj $nj --cmd "$cmd" \
                       --use-gpu false \
                       --scale-opts '--transition-scale=1.0 --self-loop-scale=1.0 --acoustic-scale=1.0' \
                       data/train data/lang exp/chain/e2e_cnn_1a exp/chain/e2e_ali_train
fi

if [ $stage -le 7 ]; then
  echo "$0: Building a tree and training a regular chain model using the e2e alignments..."
  echo "Date: $(date)."
  local/chain/run_cnn_e2eali_1b.sh --nj $nj
fi
