#!/bin/bash
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/ENRON_FIXED_20251114_024513
CSV=$RESULTS_DIR/performance.csv

echo "RESUMING Enron VF3PDL from test 23/56"
echo "Starting at: sparse 32v @ 8 threads"

# Arrays for remaining tests
declare -a tests=(
    "sparse 32 8"
    "sparse 32 16"
    "sparse 32 32"
    "sparse 32 48"
    "sparse 32 64"
    # Dense tests
    "dense 8 1"
    "dense 8 4"
    "dense 8 8"
    "dense 8 16"
    "dense 8 32"
    "dense 8 48"
    "dense 8 64"
    "dense 16 1"
    "dense 16 4"
    "dense 16 8"
    "dense 16 16"
    "dense 16 32"
    "dense 16 48"
    "dense 16 64"
    "dense 24 1"
    "dense 24 4"
    "dense 24 8"
    "dense 24 16"
    "dense 24 32"
    "dense 24 48"
    "dense 24 64"
    "dense 32 1"
    "dense 32 4"
    "dense 32 8"
    "dense 32 16"
    "dense 32 32"
    "dense 32 48"
    "dense 32 64"
)

count=23
total=56

for test in "${tests[@]}"; do
    read -r type size threads <<< "$test"
    echo "[$count/$total] ${type} ${size}v @ ${threads}t"
    
    # Add memory check before each test
    mem_available=$(free -m | awk 'NR==2{print $7}')
    if [ $mem_available -lt 10000 ]; then
        echo "  WARNING: Low memory ($mem_available MB), waiting..."
        sleep 60
    fi
    
    /usr/bin/time -v -o $RESULTS_DIR/time_output.txt \
        bash -c "timeout 90s ~/vf3lib/bin/vf3p \
            ~/vf3_test_enron_NEW/query_${type}_${size}v_1_NO_LABELS.graph \
            ~/vf3_test_enron_NEW/enron_NO_LABELS.graph \
            -a 2 -t $threads -l 0 -h 3" \
        > $RESULTS_DIR/vf3_output.txt 2>&1
    
    # Parse results (same as before)
    result=$(cat $RESULTS_DIR/vf3_output.txt | grep -E "^[0-9]+ [0-9\.]+ [0-9\.]+" | head -1)
    if [ -n "$result" ]; then
        sol=$(echo "$result" | awk '{print $1}')
        first=$(echo "$result" | awk '{print $2}')
        total_time=$(echo "$result" | awk '{print $3}')
        status="OK"
    else
        sol=0; first=0; total_time=90
        status="TIMEOUT"
    fi
    
    max_mem=$(grep "Maximum resident" $RESULTS_DIR/time_output.txt | awk '{print $6}')
    cpu=$(grep "Percent of CPU" $RESULTS_DIR/time_output.txt | awk '{print $7}' | tr -d '%')
    
    echo "$type,$size,$threads,$sol,$first,$total_time,$max_mem,$cpu,,page,$status" >> $CSV
    echo "  → $sol solutions, ${max_mem}KB memory"
    
    count=$((count+1))
done

echo "✅ COMPLETE! All 56 tests done!"
