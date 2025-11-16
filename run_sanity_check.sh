#!/bin/bash

RESULT_DIR=~/vf3lib/results/sanity_check/run_ALL_$(date +%Y%m%d_%H%M%S)
mkdir -p "$RESULT_DIR"
cd "$RESULT_DIR"

VF3P=~/vf3lib/bin/vf3p
TEST_DIR=~/vf3lib/test
CSV_FILE="sanity_results_ALL.csv"

echo "Query,Target,Threads,Solutions,FirstTime_s,TotalTime_s,Status" > "$CSV_FILE"

run_test() {
    local query=$1
    local target=$2
    local threads=$3
    local name=$(basename $query .sub.grf)

    echo "Testing: $name with $threads threads..."

    OUTPUT=$(timeout 30s "$VF3P" "$query" "$target" -a 2 -t "$threads" -l 0 -h 3 2>&1 | tail -1)
    EXIT_CODE=$?

    if [[ $EXIT_CODE -eq 124 ]]; then
        STATUS="TIMEOUT"
    elif [[ $EXIT_CODE -eq 0 ]]; then
        STATUS="OK"
    else
        STATUS="ERROR"
    fi

    SOLUTIONS=$(echo "$OUTPUT" | awk '{print $1}')
    FIRST_TIME=$(echo "$OUTPUT" | awk '{print $2}')
    TOTAL_TIME=$(echo "$OUTPUT" | awk '{print $3}')

    echo "$name,$threads,$SOLUTIONS,$FIRST_TIME,$TOTAL_TIME,$STATUS" >> "$CSV_FILE"
}

# Test ALL query/target pairs with 1, 2, 4, 8 threads
for THREADS in 1 2 4 8; do
    run_test "$TEST_DIR/bvg1.sub.grf" "$TEST_DIR/bvg1.grf" "$THREADS"
    run_test "$TEST_DIR/bvg1_2.sub.grf" "$TEST_DIR/bvg1.grf" "$THREADS"
    run_test "$TEST_DIR/bvg1_3.sub.grf" "$TEST_DIR/bvg1.grf" "$THREADS"
    run_test "$TEST_DIR/bvg1_4.sub.grf" "$TEST_DIR/bvg1.grf" "$THREADS"
    run_test "$TEST_DIR/bvg2.sub.grf" "$TEST_DIR/bvg2.grf" "$THREADS"
    run_test "$TEST_DIR/bvg3.sub.grf" "$TEST_DIR/bvg3.grf" "$THREADS"
    run_test "$TEST_DIR/m2d1.sub.grf" "$TEST_DIR/m2d1.grf" "$THREADS"
    run_test "$TEST_DIR/m2d2.sub.grf" "$TEST_DIR/m2d2.grf" "$THREADS"
    run_test "$TEST_DIR/rand1.sub.grf" "$TEST_DIR/rand1.grf" "$THREADS"
    run_test "$TEST_DIR/rand2.sub.grf" "$TEST_DIR/rand2.grf" "$THREADS"
    run_test "$TEST_DIR/rand3.sub.grf" "$TEST_DIR/rand3.grf" "$THREADS"
    run_test "$TEST_DIR/rand4.sub.grf" "$TEST_DIR/rand4.grf" "$THREADS"
    run_test "$TEST_DIR/rnd_ldg1.sub.grf" "$TEST_DIR/rnd_ldg1.grf" "$THREADS"
    run_test "$TEST_DIR/si2_b03_m400_37.sub.grf" "$TEST_DIR/si2_b03_m400_37.grf" "$THREADS"
    run_test "$TEST_DIR/si2_b03m_m800_22.sub.grf" "$TEST_DIR/si2_b03m_m800_22.grf" "$THREADS"
    run_test "$TEST_DIR/si2_b06m_m400_96.sub.grf" "$TEST_DIR/si2_b06m_m400_96.grf" "$THREADS"
    run_test "$TEST_DIR/si2_b09m_m400_01.sub.grf" "$TEST_DIR/si2_b09_m400_37.grf" "$THREADS"
    run_test "$TEST_DIR/si2_rnd_eta04_m1000_00.sub.grf" "$TEST_DIR/si2_rnd_eta04_m1000_00.grf" "$THREADS"
    run_test "$TEST_DIR/si2_rnd_eta04_m750_20.sub.grf" "$TEST_DIR/si2_rnd_eta04_m750_20.grf" "$THREADS"
done

echo ""
echo "Sanity check ALL complete! Results:"
cat "$CSV_FILE"
EOF

