#!/bin/bash

# This script uses weight transfer as a transfer learning method to transfer
# already trained neural net model on wsj to rm.
#
# Model preparation: The last layer (prefinal and output layer) from
# already-trained wsj model is removed and 3 randomly initialized layer
# (new tdnn layer, prefinal, and output) are added to the model.
#
# Training: The transferred layers are retrained with smaller learning-rate,
# while new added layers are trained with larger learning rate using rm data.
# The chain config is as in run_tdnn_5n.sh and the result is:
#System tdnn_5n tdnn_wsj_rm_1a
#WER      2.71     1.68
set -e

# configs for 'chain'
stage=0
nj=8
train_stage=-10
get_egs_stage=-10
dir=exp/chain/tdnn_kh_fa_1a
xent_regularize=0.1


# configs for transfer learning
src_mdl=exp/chain/e2e_cnn_1a/final.mdl # Input chain model
                                                   # trained on source dataset (wsj).
                                                   # This model is transfered to the target domain.
common_egs_dir=
primary_lr_factor=0.25 # The learning-rate factor for transferred layers from source
                       # model. e.g. if 0, the paramters transferred from source model
                       # are fixed.
                       # The learning-rate factor for new added layers is 1.0.

# End configuration section.

echo "$0 $@"  # Print the command line for logging

. ./cmd.sh
. ./path.sh
. ./utils/parse_options.sh

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

ali_dir=exp/chain/e2e_ali_train
lat_dir=exp/chain/e2e_train_lats
treedir=exp/chain/transfer_tree
lang=data/lang_chain_transfer
for f in data/train/feats.scp $ali_dir/ali.1.gz $ali_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

# local/online/run_nnet2_common.sh  --stage $stage \
#                                   --ivector-dim $ivector_dim \
#                                   --nnet-affix "$nnet_affix" \
#                                   --mfcc-config $src_mfcc_config \
#                                   --extractor $src_ivec_extractor_dir || exit 1;

if [ $stage -le 1 ]; then
  echo "$0: creating lang directory $lang with chain-type topology"
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  if [ -d $lang ]; then
    if [ $lang/L.fst -nt data/lang/L.fst ]; then
      echo "$0: $lang already exists, not overwriting it; continuing"
    else
      echo "$0: $lang already exists and seems to be older than data/lang..."
      echo " ... not sure what to do.  Exiting."
      exit 1;
    fi
  else
    cp -r data/lang $lang
    silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
    # Use our special topology... note that later on may have to tune this
    # topology.
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo
  fi
fi

if [ $stage -le 2 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  steps/nnet3/align_lats.sh --nj $nj --cmd "$cmd" \
                            --acoustic-scale 1.0 \
                            --scale-opts '--transition-scale=1.0 --self-loop-scale=1.0' \
                            data/train data/lang exp/chain/e2e_cnn_1a $lat_dir
  echo "" >$lat_dir/splice_opts
fi

if [ $stage -le 3 ]; then
  #Build a tree using our new topology.
  steps/nnet3/chain/build_tree.sh --frame-subsampling-factor 4 \
    --alignment-subsampling-factor 1 \
    --context-opts "--context-width=2 --central-position=1" \
    --cmd "$cmd" 1200 data/train $lang $ali_dir $treedir || exit 1;
fi


if [ $stage -le 4 ]; then
  echo "$0: Create neural net configs using the xconfig parser for";
  echo " generating new layers, that are specific to rm. These layers ";
  echo " are added to the transferred part of the wsj network.";
  num_targets=$(tree-info --print-args=false $treedir/tree |grep num-pdfs|awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
  mkdir -p $dir
  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  relu-renorm-layer name=tdnn-target input=tdnn3.batchnorm dim=450
  ## adding the layers for chain branch
  relu-renorm-layer name=prefinal-chain input=tdnn-target dim=450 target-rms=0.5
  output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5
  relu-renorm-layer name=prefinal-xent input=tdnn-target dim=450 target-rms=0.5
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5
EOF
  steps/nnet3/xconfig_to_configs.py --existing-model $src_mdl \
    --xconfig-file  $dir/configs/network.xconfig  \
    --config-dir $dir/configs/

  # Set the learning-rate-factor to be primary_lr_factor for transferred layers "
  # and adding new layers to them.
  $train_cmd $dir/log/generate_input_mdl.log \
    nnet3-copy --edits="set-learning-rate-factor name=* learning-rate-factor=$primary_lr_factor" $src_mdl - \| \
      nnet3-init --srand=1 - $dir/configs/final.config $dir/input.raw  || exit 1;
fi

if [ $stage -le 5 ]; then
  echo "$0: generate egs for chain to train new model on rm dataset."
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
    utils/create_split_dir.pl \
     /export/b0{3,4,5,6}/$USER/kaldi-data/egs/rm-$(date +'%m_%d_%H_%M')/s5/$dir/egs/storage $dir/egs/storage
  fi
  ivector_dir=
  # if $use_ivector; then ivector_dir="exp/nnet2${nnet_affix}/ivectors" ; fi

  steps/nnet3/chain/train.py --stage $train_stage \
    --cmd "$cmd" \
    --trainer.input-model $dir/input.raw \
    --feat.online-ivector-dir "$ivector_dir" \
    --chain.xent-regularize $xent_regularize \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.00005 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=200" \
    --egs.dir "$common_egs_dir" \
    --egs.opts "--frames-overlap-per-eg 0" \
    --egs.chunk-width 150 \
    --trainer.num-chunk-per-minibatch=128 \
    --trainer.frames-per-iter 1000000 \
    --trainer.num-epochs 3 \
    --trainer.optimization.num-jobs-initial=2 \
    --trainer.optimization.num-jobs-final=4 \
    --trainer.optimization.initial-effective-lrate=0.005 \
    --trainer.optimization.final-effective-lrate=0.0005 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs true \
    --feat-dir data/train \
    --tree-dir $treedir \
    --lat-dir $lat_dir \
    --dir $dir || exit 1;
fi

if [ $stage -le 6 ]; then
  # Note: it might appear that this $lang directory is mismatched, and it is as
  # far as the 'topo' is concerned, but this script doesn't read the 'topo' from
  # the lang directory.
  # ivec_opt=""
  # if $use_ivector;then
  #   ivec_opt="--online-ivector-dir exp/nnet2${nnet_affix}/ivectors_test"
  # fi
  utils/mkgraph.sh --self-loop-scale 1.0 data/lang_test $dir $dir/graph
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --scoring-opts "--min-lmwt 1" \
    --nj 4 --cmd "$cmd" \
    $dir/graph data/test $dir/decode_test || exit 1;
fi