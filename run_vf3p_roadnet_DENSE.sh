#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/roadNet-CA_VF3PDL_DENSE_${TIMESTAMP}
mkdir -p $RESULTS_DIR

SUMMARY=${RESULTS_DIR}/summary.txt
CSV=${RESULTS_DIR}/results.csv

echo "VF3PDL roadNet-CA DENSE Test" | tee $SUMMARY
echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,Status" > $CSV

for threads in 32 48 64; do
    for size in 8 16 24 32; do
        query=~/vf3_test_roadnet/query_dense_${size}v_1_NO_LABELS.graph
        
        if [ -f "$query" ]; then
            echo "=== dense ${size}v, t=${threads} ===" | tee -a $SUMMARY
            
            if [ "$size" = "8" ] || [ "$size" = "16" ]; then
                TIMEOUT=420
            else
                TIMEOUT=0
            fi
            
            if [ "$TIMEOUT" -gt 0 ]; then
                result=$(timeout ${TIMEOUT}s ./bin/vf3p $query ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph -a 2 -t $threads -l 0 -h 3 2>&1 | tee -a $SUMMARY | tail -1)
            else
                result=$(./bin/vf3p $query ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph -a 2 -t $threads -l 0 -h 3 2>&1 | tee -a $SUMMARY | tail -1)
            fi
            
            echo "$result" | awk -v s="$size" -v th="$threads" '{printf "dense,%s,%s,%s\n", s, th, $0}' >> $CSV
        fi
    done
done
echo "Completed: $(date)" | tee -a $SUMMARY
