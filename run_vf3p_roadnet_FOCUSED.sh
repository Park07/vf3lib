#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/roadNet-CA_FOCUSED_${TIMESTAMP}
mkdir -p $RESULTS_DIR

SUMMARY=${RESULTS_DIR}/summary.txt
CSV=${RESULTS_DIR}/results.csv

echo "VF3PLS roadNet-CA Complete Run" | tee $SUMMARY
echo "===============================" | tee -a $SUMMARY
echo "Threads: 32, 48, 64" | tee -a $SUMMARY
echo "Types: sparse, dense" | tee -a $SUMMARY
echo "Sizes: 8v, 16v, 24v, 32v" | tee -a $SUMMARY
echo "Started: $(date)" | tee -a $SUMMARY
echo "" | tee -a $SUMMARY

echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,Status" > $CSV

for threads in 32 48 64; do
    for type in sparse dense; do
        for size in 8 16 24 32; do
            query=~/vf3_test_roadnet/query_${type}_${size}v_1_NO_LABELS.graph
            
            if [ -f "$query" ]; then
                echo "" | tee -a $SUMMARY
                echo "=== ${type} ${size}v, t=${threads} ===" | tee -a $SUMMARY
                echo "Start: $(date +'%Y-%m-%d %H:%M:%S')" | tee -a $SUMMARY
                
                # Run to completion (no timeout)
                result=$(./bin/vf3p \
                  $query \
                  ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
                  -a 2 -t $threads -l 8 -h 3 2>&1 | tee -a $SUMMARY | tail -1)
                
                # Parse result and add to CSV
                echo "$result" | awk -v t="$type" -v s="$size" -v th="$threads" \
                  '{if (NF==3) status="COMPLETE"; else if ($NF=="TIMEOUT") status="TIMEOUT"; else status="UNKNOWN"; 
                    printf "%s,%s,%s,%s\n", t, s, th, $0}' >> $CSV
                
                echo "End: $(date +'%Y-%m-%d %H:%M:%S')" | tee -a $SUMMARY
            fi
        done
    done
done

echo "" | tee -a $SUMMARY
echo "Completed: $(date)" | tee -a $SUMMARY
