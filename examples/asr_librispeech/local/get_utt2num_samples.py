#!/usr/bin/env python

from argparse import ArgumentParser

import kaldiio as kio


def main():
    parser = ArgumentParser()
    parser.add_argument('wavscp')
    parser.add_argument('utt2num_samples')
    args = parser.parse_args()
    wavscp = kio.load_scp(args.wavscp)
    with open(args.utt2num_samples, 'w') as f:
        for utt_id in wavscp:
            rate, samples = wavscp[utt_id]
            print(utt_id, len(samples), file=f)


if __name__ == '__main__':
    main()
