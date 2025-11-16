#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/ENRON_VF3PDL_${TIMESTAMP}
CSV=$RESULTS_DIR/results.csv

mkdir -p $RESULTS_DIR

echo "VF3PDL Enron Test Suite - 90s timeout" | tee $RESULTS_DIR/summary.txt
echo "Started: $(date)" | tee -a $RESULTS_DIR/summary.txt
echo "" | tee -a $RESULTS_DIR/summary.txt

echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,Status" > $CSV

total_tests=$((8 * 7))  # 8 queries × 7 thread counts
current=0

for type in sparse dense; do
    for size in 8 16 24 32; do
        for threads in 1 4 8 16 32 48 64; do
            current=$((current + 1))
            query=~/vf3_test_enron_NEW/query_${type}_${size}v_1_NO_LABELS.graph
            data=~/vf3_test_enron_NEW/enron_NO_LABELS.graph
            
            echo "[$current/$total_tests] ${type} ${size}v @ ${threads}t (90s timeout)"
            
            result=$(timeout 90s ~/vf3lib/bin/vf3p $query $data -a 2 -t $threads -l 0 -h 3 2>&1)
            exit_code=$?
            
            if [[ $exit_code -eq 124 ]]; then
                echo "$type,$size,$threads,0,0,90,TIMEOUT" >> $CSV
                echo "  → TIMEOUT at 90s"
            elif [[ $exit_code -eq 0 ]]; then
                nums=$(echo "$result" | grep -E "^[0-9]+ [0-9\.]+ [0-9\.]+$")
                if [ -n "$nums" ]; then
                    sol=$(echo "$nums" | awk '{print $1}')
                    first=$(echo "$nums" | awk '{print $2}')
                    total=$(echo "$nums" | awk '{print $3}')
                    echo "$type,$size,$threads,$sol,$first,$total,OK" >> $CSV
                    echo "  → $sol solutions in ${total}s"
                else
                    echo "$type,$size,$threads,0,0,0,ERROR" >> $CSV
                    echo "  → ERROR: No output"
                fi
            else
                echo "$type,$size,$threads,0,0,0,ERROR_${exit_code}" >> $CSV
                echo "  → ERROR code $exit_code"
            fi
        done
    done
done

echo "" | tee -a $RESULTS_DIR/summary.txt
echo "Completed: $(date)" | tee -a $RESULTS_DIR/summary.txt
echo "Results saved to: $CSV" | tee -a $RESULTS_DIR/summary.txt

# Quick summary
echo "" | tee -a $RESULTS_DIR/summary.txt
echo "=== SUMMARY ===" | tee -a $RESULTS_DIR/summary.txt
grep -c "OK" $CSV | xargs echo "Successful tests:" | tee -a $RESULTS_DIR/summary.txt
grep -c "TIMEOUT" $CSV | xargs echo "Timeouts:" | tee -a $RESULTS_DIR/summary.txt
grep -c "ERROR" $CSV | xargs echo "Errors:" | tee -a $RESULTS_DIR/summary.txt
