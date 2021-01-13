#!/usr/bin/env python
from argparse import ArgumentParser

import kaldiio
import torch
from kaldiio import WriteHelper
from torchaudio.transforms import MelSpectrogram


def main():
    parser = ArgumentParser()
    parser.add_argument('wavscp')
    parser.add_argument('wxspecifier')
    parser.add_argument('--write-num-frames')
    args = parser.parse_args()

    ms = MelSpectrogram(sample_rate=16000, n_mels=80, n_fft=400, win_length=400, hop_length=160)

    if args.write_num_frames is not None:
        utt2num_frames = open(args.write_num_frames, 'w')
    else:
        utt2num_frames = None

    with WriteHelper(args.wxspecifier, compression_method=1) as writer:
        for reco_id, (sampling_rate, samples) in kaldiio.load_scp_sequential(args.wavscp):
            samples = torch.from_numpy(samples).to(dtype=torch.float32)
            feats = ms(samples.unsqueeze(0)).transpose(2, 1).squeeze(0)
            writer(reco_id, feats.numpy())
            if utt2num_frames is not None:
                print(reco_id, feats.shape[0], file=utt2num_frames)


if __name__ == '__main__':
    main()
