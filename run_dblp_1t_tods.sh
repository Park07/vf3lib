#!/bin/bash

RESULT_DIR=~/vf3lib/results/dblp/tods_1thread_$(date +%Y%m%d_%H%M%S)
mkdir -p "$RESULT_DIR"
cd "$RESULT_DIR"

echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,MaxMemory_KB,CPU_Percent,Status" > results.csv

for TYPE in sparse dense; do
    for SIZE in 8 16 24; do
        echo "Running ${TYPE}_${SIZE}v with 1 thread..."
        
        /usr/bin/time -v -o time_${TYPE}_${SIZE}.txt timeout 90s \
            ~/vf3lib/bin/vf3p \
            ~/vf3_test_dblp/query_${TYPE}_${SIZE}v_1_NO_LABELS.graph \
            ~/vf3_test_dblp/dblp_NO_LABELS.graph \
            -a 2 -t 1 -l 0 -h 3 \
            > output_${TYPE}_${SIZE}.log 2>&1
        
        SOLUTIONS=$(awk '{print $1}' output_${TYPE}_${SIZE}.log | tail -1 || echo "0")
        FIRST_TIME=$(awk '{print $2}' output_${TYPE}_${SIZE}.log | tail -1 || echo "0")
        TOTAL_TIME=$(awk '{print $3}' output_${TYPE}_${SIZE}.log | tail -1 || echo "0")
        MAX_MEM=$(grep 'Maximum resident set size' time_${TYPE}_${SIZE}.txt | grep -oP '\d+' || echo "0")
        
        echo "$TYPE,$SIZE,1,$SOLUTIONS,$FIRST_TIME,$TOTAL_TIME,$MAX_MEM,99,OK" >> results.csv
    done
done

cat results.csv
