#!/usr/bin/env bash

# Copyright    2020  Johns Hopkins University (Piotr Żelasko)
# Apache 2.0

# This script creates utt2num_samples file in a data dir in a parallelized way.

nj=4
cmd=run.pl

. ./utils/parse_options.sh
. ./path.sh

set -euo pipefail

if [ $# != 1 ]; then
  echo "Usage: $0 <datadir>"
  echo " This script creates utt2num_samples file in a data dir in a parallelized way."
  echo "Options: "
  echo "  --nj <nj>                                        # number of parallel jobs"
  echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
  exit 1;
fi


export LC_ALL=C

dir=$1

if [ -f $dir/utt2num_samples ]; then
  wav_count=$(wc -l $dir/wav.scp | cut -f1 -d' ')
  samp_count=$(wc -l $dir/utt2num_samples | cut -f1 -d' ')
  if [ $wav_count -eq $samp_count ]; then
    echo "$dir/utt2num_samples already exists and seems correct; we're not re-computing it."
    exit 0;
  fi
fi

splitdir=$dir/utt2num_samples_split$nj
mkdir -p $splitdir

split_wavscp=""
for n in $(seq $nj); do
  split_wavscp="$split_wavscp $splitdir/wav.scp.$n"
done

utils/split_scp.pl $dir/wav.scp $split_wavscp

$cmd JOB=1:$nj $splitdir/log/get_utt2num_samples.JOB.log \
      python3 local/get_utt2num_samples.py $splitdir/wav.scp.JOB \
      $splitdir/utt2num_samples.JOB

for n in $(seq $nj); do
  cat $splitdir/utt2num_samples.$n
done > $dir/utt2num_samples

