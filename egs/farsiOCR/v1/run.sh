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
  #local/khatt_normalize.sh
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
  cat data/train/text > data/local/lm/train.lines
  cat data/test/text | awk '{ for(i=2;i<=NF;i++) print $i;}' | sort -u >test_words.txt
  cat data/train/text | awk '{ for(i=2;i<=NF;i++) print $i;}' | sort -u >train_words.txt
  utils/filter_scp.pl --exclude train_words.txt test_words.txt > diff.txt
  cat diff.txt | awk '{print "id " $1}' >> data/local/lm/train.lines
  cat data/local/lm/train.lines >> final_lm
  local/prepare_lm.sh --ngram 3 final_lm data/lang
fi

if [ $stage -le 3 ]; then
  # Feature Extraction
  echo "Feature Extraction"
  local/feature_extraction.sh

  for set in test train
  do
    select-feats 11-38 ark,t:data/feats/feats_${set}.ark,t ark,scp:data/feats/fcombined_$set.ark,data/$set/feats.scp
    steps/compute_cmvn_stats.sh --fake data/$set data/cmvn data/cmvn
    utils/validate_data_dir.sh --no-wav data/$set/
  done
fi

if [ $stage -le 4 ]; then
  steps/train_mono.sh --nj $nj \
    data/train \
    data/lang \
    exp/mono
fi

if [ $stage -le 5 ]; then
  utils/mkgraph.sh --mono data/lang \
    exp/mono \
    exp/mono/graph
  steps/decode.sh --nj $nj --cmd $cmd \
    exp/mono/graph \
    data/test \
    exp/mono/decode_test
fi

if [ $stage -le 6 ]; then
  steps/align_si.sh --nj $nj \
    data/train data/lang \
    exp/mono \
    exp/mono_ali
  steps/train_deltas.sh \
    500 20000 data/train data/lang \
    exp/mono_ali \
    exp/tri
fi

if [ $stage -le 7 ]; then
  utils/mkgraph.sh data/lang \
    exp/tri \
    exp/tri/graph
  steps/decode.sh --nj $nj --cmd $cmd \
    exp/tri/graph \
    data/test \
    exp/tri/decode_test
fi

if [ $stage -le 8 ]; then
  steps/align_si.sh --nj $nj --cmd $cmd \
    data/train data/lang \
    exp/mono \
    exp/mono_ali
  steps/train_lda_mllt.sh --cmd $cmd \
    --splice-opts "--left-context=3 --right-context=3" \
    500 20000 \
    data/train data/lang \
    exp/mono_ali exp/tri2
fi

if [ $stage -le 9 ]; then
  utils/mkgraph.sh data/lang \
    exp/tri2 \
    exp/tri2/graph
  steps/decode.sh --nj $nj --cmd $cmd \
    exp/tri2/graph \
    data/test \
    exp/tri2/decode_test
fi

if [ $stage -le 10 ]; then
  steps/align_fmllr.sh --nj $nj --cmd $cmd \
    --use-graphs true \
    data/train data/lang \
    exp/tri2 \
    exp/tri2_ali
  steps/train_sat.sh --cmd $cmd \
    500 20000 \
    data/train data/lang \
    exp/tri2_ali exp/tri3
fi

if [ $stage -le 11 ]; then
  utils/mkgraph.sh data/lang \
    exp/tri3 \
    exp/tri3/graph
  steps/decode_fmllr.sh --nj $nj --cmd $cmd \
    exp/tri3/graph \
    data/test \
    exp/tri3/decode_test
fi

if [ $stage -le 12 ]; then
  steps/align_fmllr.sh --nj $nj --cmd $cmd \
    --use-graphs true \
    data/train data/lang \
    exp/tri3 \
    exp/tri3_ali
fi

if [ $stage -le 13 ]; then
  local/chain/run_cnn_1a.sh
fi

if [ $stage -le 14 ]; then
  local/chain/run_cnn_chainali_1b.sh
fi
