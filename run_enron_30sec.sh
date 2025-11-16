#!/bin/bash

RESULT_DIR=~/vf3lib/results/enron_30sec/run_$(date +%Y%m%d_%H%M%S)
mkdir -p "$RESULT_DIR"
cd "$RESULT_DIR"

VF3P=~/vf3lib/bin/vf3p
ENRON_DIR=~/vf3_test_enron_NEW
CSV_FILE="enron_30sec.csv"

echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,MaxMemory_KB,CPU_Percent,Status" > "$CSV_FILE"

run_test() {
    local type=$1
    local size=$2
    local threads=$3
    
    QUERY="${ENRON_DIR}/query_${type}_${size}v_1_NO_LABELS.graph"
    TARGET="${ENRON_DIR}/enron_NO_LABELS.graph"
    
    TIME_FILE="time_${type}_${size}_t${threads}.txt"
    OUTPUT_FILE="output_${type}_${size}_t${threads}.log"
    
    echo "Running: $type ${size}v with $threads threads (30 sec)..."
    
    /usr/bin/time -v -o "$TIME_FILE" timeout 30s \
        "$VF3P" "$QUERY" "$TARGET" -a 2 -t "$threads" -l 0 -h 3 \
        > "$OUTPUT_FILE" 2>&1
    
    EXIT_CODE=$?
    
    SOLUTIONS=$(awk '{print $1}' "$OUTPUT_FILE" | tail -1 || echo "0")
    FIRST_TIME=$(awk '{print $2}' "$OUTPUT_FILE" | tail -1 || echo "0")
    TOTAL_TIME=$(awk '{print $3}' "$OUTPUT_FILE" | tail -1 || echo "0")
    MAX_MEM=$(grep 'Maximum resident set size' "$TIME_FILE" | grep -oP '\d+' || echo "0")
    CPU_PCT=$(grep 'Percent of CPU' "$TIME_FILE" | grep -oP '\d+' || echo "0")
    
    if [[ $EXIT_CODE -eq 124 ]]; then
        STATUS="TIMEOUT"
    elif [[ $EXIT_CODE -eq 137 ]]; then
        STATUS="KILLED"
    elif [[ $EXIT_CODE -ne 0 ]]; then
        STATUS="ERROR"
    else
        STATUS="OK"
    fi
    
    echo "$type,$size,$threads,$SOLUTIONS,$FIRST_TIME,$TOTAL_TIME,$MAX_MEM,$CPU_PCT,$STATUS" >> "$CSV_FILE"
}

# All configs with 30s timeout
for TYPE in sparse dense; do
    for SIZE in 8 16 24 32; do
        for THREADS in 1 8 16 32 48 64; do
            run_test "$TYPE" "$SIZE" "$THREADS"
        done
    done
done

echo ""
echo "ENRON 30-second baseline complete! Results:"
cat "$CSV_FILE"
