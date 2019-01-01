#!/bin/bash

# Copyright 2012  Johns Hopkins University (author: Daniel Povey)  Tony Robinson
#           2017  Hainan Xu
#           2017  Ke Li

# Begin configuration section.

dir=exp/rnnlm_rescore
embedding_dim=800
lstm_rpd=200
lstm_nrpd=200
embedding_l2=0.001 # embedding layer l2 regularize
comp_l2=0.001 # component-level l2 regularize
output_l2=0.001 # output-layer l2 regularize
epochs=20
stage=-10
train_stage=-10

# variables for rnnlm rescoring
ac_model_dir=exp/chain/cnn_e2eali_1b
ngram_order=4
decode_dir_suffix=rnnlm
cmd=$train_cmd

. ./cmd.sh
. ./utils/parse_options.sh


text=data/train/text
wordlist=data/lang/words.txt
text_dir=data/rnnlm/text
mkdir -p $dir/config
set -e

for f in $text $wordlist; do
  [ ! -f $f ] && \
    echo "$0: expected file $f to exist." && exit 1
done

if [ $stage -le 0 ]; then
  mkdir -p $text_dir
  echo -n >$text_dir/dev.txt
  # hold out one in every 500 lines as dev data.
  cat $text | cut -d' ' -f2- | awk -v text_dir=$text_dir '{if(NR%500 == 0) { print >text_dir"/dev.txt"; } else {print;}}' >$text_dir/khatt.txt
fi

if [ $stage -le 1 ]; then
  # the training scripts require that <s>, </s> and <brk> be present in a particular
  # order.
  cp $wordlist $dir/config/ 
  n=`cat $dir/config/words.txt | wc -l` 
  echo "<brk> $n" >> $dir/config/words.txt 

  # words that are not present in words.txt but are in the training or dev data, will be
  # mapped to <SPOKEN_NOISE> during training.
  echo "<unk>" >$dir/config/oov.txt

  cat > $dir/config/data_weights.txt <<EOF
khatt   1   1.0
EOF

  rnnlm/get_unigram_probs.py --vocab-file=$dir/config/words.txt \
                             --unk-word="<unk>" \
                             --data-weights-file=$dir/config/data_weights.txt \
                             $text_dir | awk 'NF==2' >$dir/config/unigram_probs.txt

  # choose features
  rnnlm/choose_features.py --unigram-probs=$dir/config/unigram_probs.txt \
                           --use-constant-feature=true \
                           --top-word-features=50000 \
                           --min-frequency 1.0e-03 \
                           --special-words='<s>,</s>,<brk>,<unk>' \
                           $dir/config/words.txt > $dir/config/features.txt

lstm_opts="l2-regularize=$comp_l2"
tdnn_opts="l2-regularize=$comp_l2"
output_opts="l2-regularize=$output_l2"

  cat >$dir/config/xconfig <<EOF
input dim=$embedding_dim name=input
relu-renorm-layer name=tdnn1 dim=$embedding_dim $tdnn_opts input=Append(0, IfDefined(-1)) 
fast-lstmp-layer name=lstm1 cell-dim=$embedding_dim recurrent-projection-dim=$lstm_rpd non-recurrent-projection-dim=$lstm_nrpd $lstm_opts
relu-renorm-layer name=tdnn2 dim=$embedding_dim $tdnn_opts input=Append(0, IfDefined(-2))
fast-lstmp-layer name=lstm2 cell-dim=$embedding_dim recurrent-projection-dim=$lstm_rpd non-recurrent-projection-dim=$lstm_nrpd $lstm_opts
relu-renorm-layer name=tdnn3 dim=$embedding_dim $tdnn_opts input=Append(0, IfDefined(-1))
output-layer name=output $output_opts include-log-softmax=false dim=$embedding_dim
EOF
  rnnlm/validate_config_dir.sh $text_dir $dir/config
fi

if [ $stage -le 2 ]; then
  # the --unigram-factor option is set larger than the default (100)
  # in order to reduce the size of the sampling LM, because rnnlm-get-egs
  # was taking up too much CPU (as much as 10 cores).
  rnnlm/prepare_rnnlm_dir.sh --unigram-factor 200.0 \
                             $text_dir $dir/config $dir
fi

if [ $stage -le 3 ]; then
  rnnlm/train_rnnlm.sh --num-jobs-initial 1 --num-jobs-final 1 \
                       --embedding_l2 $embedding_l2 \
                       --stage 1 --num-epochs $epochs --cmd "$cmd" $dir
fi

LM=tgpr
if [ $stage -le 4 ]; then
  for decode_set in test validate; do
    decode_dir=${ac_model_dir}/decode_${decode_set}

    # Lattice rescoring
    rnnlm/lmrescore_pruned.sh \
      --cmd "$decode_cmd" \
      --weight 0.8 --max-ngram-order $ngram_order \
      data/lang $dir \
      data/${decode_set} ${decode_dir} \
      ${decode_dir}_${decode_dir_suffix} &
  done
  wait
fi
