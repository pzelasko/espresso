#!/bin/bash
# Copyright    2020       Johns Hopkins University (Author: Piotr Żelasko)
# Apache 2.0

# Begin configuration section.
nj=4
cmd=run.pl
#fbank_config=conf/fbank.conf
write_utt2num_frames=true # if true writes utt2num_frames
# End configuration section.

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
   echo "Usage: $0 [options] <data-dir> <fbank-dir>";
   echo "e.g.: $0 data/train fbank_ta/train"
   echo "Options: "
#   echo "  --fbank-config <config-file>                     # config passed to compute-fbank-feats "
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --write-utt2num-frames <true|false>     # If true, write utt2num_frames file."
   exit 1;
fi

data=$1
fbankdir=$2

# make $fbankdir an absolute pathname.
fbankdir=`perl -e '($dir,$pwd)= @ARGV; if($dir!~m:^/:) { $dir = "$pwd/$dir"; } print $dir; ' $fbankdir ${PWD}`

logdir=$fbankdir/log

# use "name" as part of name of the archive.
name=`basename $data`

mkdir -p $fbankdir || exit 1;
mkdir -p $logdir || exit 1;

if [ -f $data/feats.scp ]; then
  mkdir -p $data/.backup
  echo "$0: moving $data/feats.scp to $data/.backup"
  mv $data/feats.scp $data/.backup
fi

scp=$data/wav.scp

#required="$scp $fbank_config"
required="$scp"

for f in $required; do
  if [ ! -f $f ]; then
    echo "make_fbank_torchaudio.sh: no such file $f"
    exit 1;
  fi
done

utils/validate_data_dir.sh --no-text --no-feats $data || exit 1;

for n in $(seq $nj); do
  # the next command does nothing unless $fbankdir/storage/ exists, see
  # utils/create_data_link.pl for more info.
  utils/create_data_link.pl $fbankdir/raw_fbank_$name.$n.ark
done

opt_args=""

if $write_utt2num_frames; then
  opt_args="${opt_args} --write-num-frames $logdir/utt2num_frames.JOB"
fi

split_scps=""
for n in $(seq $nj); do
  split_scps="$split_scps $logdir/wav.$n.scp"
done

utils/split_scp.pl $scp $split_scps || exit 1;

$cmd JOB=1:$nj $logdir/make_fbank_${name}.JOB.log \
  python local/make_fbank_torchaudio.py $opt_args \
   $logdir/wav.JOB.scp \
   ark,scp:$fbankdir/raw_fbank_$name.JOB.ark,$fbankdir/raw_fbank_$name.JOB.scp

# concatenate the .scp files together.
for n in $(seq $nj); do
  cat $fbankdir/raw_fbank_$name.$n.scp || exit 1;
done > $data/feats.scp

if $write_utt2num_frames; then
  for n in $(seq $nj); do
    cat $logdir/utt2num_frames.$n || exit 1;
  done > $logdir/utt2num_frames || exit 1
fi

nf=`cat $data/feats.scp | wc -l`
nu=`cat $data/utt2spk | wc -l`
if [ $nf -ne $nu ]; then
  echo "It seems not all of the feature files were successfully ($nf != $nu);"
  echo "consider using utils/fix_data_dir.sh $data"
fi

echo "Succeeded creating filterbank features for $name"
