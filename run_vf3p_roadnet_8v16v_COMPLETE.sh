#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/roadNet-CA_8v16v_COMPLETE_${TIMESTAMP}
mkdir -p $RESULTS_DIR

SUMMARY=${RESULTS_DIR}/summary.txt
CSV=${RESULTS_DIR}/results.csv

echo "VF3PDL 8v/16v Complete Run (64 threads, no timeout)" | tee $SUMMARY
echo "====================================================" | tee -a $SUMMARY
echo "Started: $(date)" | tee -a $SUMMARY
echo "" | tee -a $SUMMARY

echo "Size,Threads,Solutions,FirstTime_s,TotalTime_s,Status" > $CSV

for size in 8 16; do
    query=~/vf3_test_roadnet/query_sparse_${size}v_1_NO_LABELS.graph
    
    echo "" | tee -a $SUMMARY
    echo "=== sparse ${size}v, t=64, NO TIMEOUT ===" | tee -a $SUMMARY
    echo "Start: $(date +'%Y-%m-%d %H:%M:%S')" | tee -a $SUMMARY
    
    # NO TIMEOUT - run to completion
    result=$(./bin/vf3p \
      $query \
      ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
      -a 2 -t 64 -l 0 -h 3 2>&1 | tee -a $SUMMARY | tail -1)
    
    echo "$result" | awk -v s="$size" '{printf "%s,64,%s\n", s, $0}' >> $CSV
    
    echo "End: $(date +'%Y-%m-%d %H:%M:%S')" | tee -a $SUMMARY
done

echo "" | tee -a $SUMMARY
echo "Completed: $(date)" | tee -a $SUMMARY
