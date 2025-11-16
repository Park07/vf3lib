#!/bin/bash

mkdir -p ~/vf3lib/results/sparse_24_64_unlimited
cd ~/vf3lib/results/sparse_24_64_unlimited

nohup ~/vf3lib/bin/vf3p \
  ~/vf3_test_enron_NEW/query_sparse_24v_1_NO_LABELS.graph \
  ~/vf3_test_enron_NEW/enron_NO_LABELS.graph \
  -a 2 -t 64 -l 0 -h 3 \
  > output.log 2>&1 &

echo $! > pid.txt
cat pid.txt
