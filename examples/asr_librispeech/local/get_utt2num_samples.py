#!/usr/bin/env python

from argparse import ArgumentParser
from pathlib import Path

import kaldiio as kio


def main():
    parser = ArgumentParser()
    parser.add_argument('data')
    args = parser.parse_args()
    data = Path(args.data)
    wavscp = kio.load_scp(str(data / 'wav.scp'))
    with (data / 'utt2num_samples').open('w') as f:
        for utt_id in wavscp:
            rate, samples = wavscp[utt_id]
            print(utt_id, len(samples), file=f)


if __name__ == '__main__':
    main()
