#!/bin/bash
cd ~/vf3lib

RESULTS_FILE=~/vf3lib/vf3p_roadnet_results_$(date +%Y%m%d_%H%M%S).txt
echo "VF3P roadNet-CA Test Results" > $RESULTS_FILE
echo "Started: $(date)" >> $RESULTS_FILE
echo "======================================" >> $RESULTS_FILE

for threads in 16 32 48 64; do
    for size in 8 16 24 32; do
        query=~/vf3_test_roadnet/query_sparse_${size}v_1_NO_LABELS.graph
        
        if [ -f "$query" ]; then
            echo "" >> $RESULTS_FILE
            echo "=== ${size}v query, ${threads} threads ===" >> $RESULTS_FILE
            
            timeout 300s ./bin/vf3p \
              $query \
              ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
              -a 2 -t $threads -l 8 -h 3 2>&1 | tee -a $RESULTS_FILE
        fi
    done
done

echo "" >> $RESULTS_FILE
echo "Completed: $(date)" >> $RESULTS_FILE
echo "Results saved to: $RESULTS_FILE"
