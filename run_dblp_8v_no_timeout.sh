#!/bin/bash

RESULT_DIR=~/vf3lib/results/dblp/8v_$(date +%Y%m%d_%H%M%S)
mkdir -p "$RESULT_DIR"
cd "$RESULT_DIR"

echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,MaxMemory_KB,Status" > results.csv

for TYPE in sparse dense; do
    for THREADS in 1 2 4; do
        /usr/bin/time -v -o time_${TYPE}_${THREADS}.txt \
            ~/vf3lib/bin/vf3p \
            ~/vf3_test_dblp/query_${TYPE}_8v_1_NO_LABELS.graph \
            ~/vf3_test_dblp/dblp_NO_LABELS.graph \
            -a 2 -t $THREADS -l 0 -h 3 \
            > output_${TYPE}_${THREADS}.log 2>&1
        
        SOLUTIONS=$(awk '{print $1}' output_${TYPE}_${THREADS}.log | tail -1)
        TOTAL_TIME=$(awk '{print $3}' output_${TYPE}_${THREADS}.log | tail -1)
        MAX_MEM=$(grep 'Maximum resident set size' time_${TYPE}_${THREADS}.txt | grep -oP '\d+')
        
        echo "$TYPE,8,$THREADS,$SOLUTIONS,0,$TOTAL_TIME,$MAX_MEM,OK" >> results.csv
    done
done

cat results.csv
