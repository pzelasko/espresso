#!/usr/bin/env bash

. ./cmd.sh
. ./path.sh


# You may set 'mic' to:
#  ihm [individual headset mic- the default which gives best results]
#  sdm1 [single distant microphone- the current script allows you only to select
#        the 1st of 8 microphones]
#  mdm8 [multiple distant microphones-- currently we only support averaging over
#       the 8 source microphones].
# ... by calling this script as, for example,
# ./run.sh --mic sdm1
# ./run.sh --mic mdm8
mic=ihm

# Train systems,
nj=30 # number of parallel jobs,
stage=1
. utils/parse_options.sh

base_mic=$(echo $mic | sed 's/[0-9]//g') # sdm, ihm or mdm
nmics=$(echo $mic | sed 's/[a-z]//g') # e.g. 8 for mdm8.

set -euo pipefail

# Path where AMI gets downloaded (or where locally available):
AMI_DIR=$PWD/wav_db # Default,
case $(hostname -d) in
  fit.vutbr.cz) AMI_DIR=/mnt/matylda5/iveselyk/KALDI_AMI_WAV ;; # BUT,
  clsp.jhu.edu) AMI_DIR=/export/corpora5/AMI/amicorpus/ ;; # JHU,
  cstr.ed.ac.uk) AMI_DIR= ;; # Edinburgh,
esac

# Download AMI corpus, You need around 130GB of free space to get whole data ihm+mdm,
if [ $stage -le 0 ]; then
  if [ -d $AMI_DIR ] && ! touch $AMI_DIR/.foo 2>/dev/null; then
    echo "$0: directory $AMI_DIR seems to exist and not be owned by you."
    echo " ... Assuming the data does not need to be downloaded.  Please use --stage 1 or more."
    exit 1
  fi
  if [ -e data/local/downloads/wget_$mic.sh ]; then
    echo "data/local/downloads/wget_$mic.sh already exists, better quit than re-download... (use --stage N)"
    exit 1
  fi
  local/ami_download.sh $mic $AMI_DIR
fi


if [ "$base_mic" == "mdm" ]; then
  PROCESSED_AMI_DIR=$AMI_DIR/beamformed
  if [ $stage -le 1 ]; then
    # for MDM data, do beamforming
    ! hash BeamformIt && echo "Missing BeamformIt, run 'cd ../../../tools/; extras/install_beamformit.sh; cd -;'" && exit 1
    local/ami_beamform.sh --cmd "$train_cmd" --nj 20 $nmics $AMI_DIR $PROCESSED_AMI_DIR
  fi
else
  PROCESSED_AMI_DIR=$AMI_DIR
fi

# Prepare original data directories data/ihm/train_orig, etc.
if [ $stage -le 2 ]; then
  local/ami_${base_mic}_data_prep.sh $PROCESSED_AMI_DIR $mic
  local/ami_${base_mic}_scoring_data_prep.sh $PROCESSED_AMI_DIR $mic dev
  local/ami_${base_mic}_scoring_data_prep.sh $PROCESSED_AMI_DIR $mic eval
fi

if [ $stage -le 3 ]; then
  for dset in train dev eval; do
    # this splits up the speakers (which for sdm and mdm just correspond
    # to recordings) into 30-second chunks.  It's like a very brain-dead form
    # of diarization; we can later replace it with 'real' diarization.
    seconds_per_spk_max=30
    [ "$mic" == "ihm" ] && seconds_per_spk_max=120  # speaker info for ihm is real,
                                                    # so organize into much bigger chunks.

    # Note: the 30 on the next line should have been $seconds_per_spk_max
    # (thanks: Pavel Denisov.  This is a bug but before fixing it we'd have to
    # test the WER impact.  I suspect it will be quite small and maybe hard to
    # measure consistently.
    utils/data/modify_speaker_info.sh --seconds-per-spk-max 30 \
      data/$mic/${dset}_orig data/$mic/$dset
  done
fi

# Feature extraction,
if [ $stage -le 4 ]; then
  for dset in train dev eval; do
    steps/make_fbank_pitch.sh --nj 40 --cmd "$train_cmd" data/$mic/$dset
    steps/compute_cmvn_stats.sh data/$mic/$dset
    utils/fix_data_dir.sh data/$mic/$dset
  done
fi

