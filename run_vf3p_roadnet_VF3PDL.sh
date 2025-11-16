#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/roadNet-CA_VF3PDL_${TIMESTAMP}
mkdir -p $RESULTS_DIR

SUMMARY=${RESULTS_DIR}/summary.txt
CSV=${RESULTS_DIR}/results.csv

echo "VF3PDL roadNet-CA Test" | tee $SUMMARY
echo "======================" | tee -a $SUMMARY
echo "Algorithm: VF3PDL (-l 0)" | tee -a $SUMMARY
echo "Threads: 32, 48, 64" | tee -a $SUMMARY
echo "Timeout: 8v/16v = 420s, 24v/32v = none" | tee -a $SUMMARY
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
                echo "Start: $(date +'%H:%M:%S')" | tee -a $SUMMARY
                
                # Set timeout based on query size
                if [ "$size" = "8" ] || [ "$size" = "16" ]; then
                    TIMEOUT=420  # 7 minutes for 8v and 16v
                else
                    TIMEOUT=0    # No timeout for 24v and 32v
                fi
                
                # Run with VF3PDL (-l 0)
                if [ "$TIMEOUT" -gt 0 ]; then
                    result=$(timeout ${TIMEOUT}s ./bin/vf3p \
                      $query \
                      ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
                      -a 2 -t $threads -l 0 -h 3 2>&1 | tee -a $SUMMARY | tail -1)
                else
                    result=$(./bin/vf3p \
                      $query \
                      ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
                      -a 2 -t $threads -l 0 -h 3 2>&1 | tee -a $SUMMARY | tail -1)
                fi
                
                # Add to CSV
                echo "$result" | awk -v t="$type" -v s="$size" -v th="$threads" \
                  '{printf "%s,%s,%s,%s\n", t, s, th, $0}' >> $CSV
                
                echo "End: $(date +'%H:%M:%S')" | tee -a $SUMMARY
            fi
        done
    done
done

echo "" | tee -a $SUMMARY
echo "Completed: $(date)" | tee -a $SUMMARY
echo "Results saved to: $RESULTS_DIR"
