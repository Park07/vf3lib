#!/bin/bash

# DBLP benchmark - VF3PDL, 8 threads, no timeout

RESULT_DIR=~/vf3lib/results/dblp_vf3pdl_8t_unlimited_$(date +%Y%m%d_%H%M%S)
mkdir -p "$RESULT_DIR"
cd "$RESULT_DIR"

DBLP_DIR=~/vf3_test_dblp
VF3P=~/vf3lib/bin/vf3p
THREADS=8
CSV_FILE="results.csv"

echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,MaxMemory_KB,CPU_Percent,Status" > "$CSV_FILE"

run_test() {
    local type=$1
    local size=$2
    
    echo "Running: $type ${size}v with $THREADS threads (NO TIMEOUT)"
    
    QUERY="${DBLP_DIR}/query_${type}_${size}v_1_NO_LABELS.graph"
    TARGET="${DBLP_DIR}/dblp_NO_LABELS.graph"
    
    TIME_FILE="time_${type}_${size}.txt"
    OUTPUT_FILE="output_${type}_${size}.log"
    
    # Run without timeout
    /usr/bin/time -v -o "$TIME_FILE" \
        "$VF3P" "$QUERY" "$TARGET" -a 2 -t "$THREADS" -l 0 -h 3 \
        > "$OUTPUT_FILE" 2>&1
    
    EXIT_CODE=$?
    
    # Parse results
    SOLUTIONS=$(awk '{print $1}' "$OUTPUT_FILE" | tail -1 || echo "0")
    FIRST_TIME=$(awk '{print $2}' "$OUTPUT_FILE" | tail -1 || echo "0")
    TOTAL_TIME=$(awk '{print $3}' "$OUTPUT_FILE" | tail -1 || echo "0")
    MAX_MEM=$(grep 'Maximum resident set size' "$TIME_FILE" | grep -oP '\d+' || echo "0")
    CPU_PCT=$(grep 'Percent of CPU' "$TIME_FILE" | grep -oP '\d+' || echo "0")
    
    if [[ $EXIT_CODE -eq 137 ]]; then
        STATUS="KILLED"
    elif [[ $EXIT_CODE -ne 0 ]]; then
        STATUS="ERROR"
    else
        STATUS="OK"
    fi
    
    echo "$type,$size,$THREADS,$SOLUTIONS,$FIRST_TIME,$TOTAL_TIME,$MAX_MEM,$CPU_PCT,$STATUS" >> "$CSV_FILE"
    echo "  Solutions: $SOLUTIONS, Time: ${TOTAL_TIME}s, Memory: ${MAX_MEM}KB, Status: $STATUS"
}

# Run all configurations
for TYPE in sparse dense; do
    for SIZE in 8 16 24 32; do
        run_test "$TYPE" "$SIZE"
    done
done

echo ""
echo "Complete! Results in: $RESULT_DIR"
cat "$CSV_FILE"
