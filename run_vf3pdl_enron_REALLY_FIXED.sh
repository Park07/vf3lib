#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/ENRON_FIXED_${TIMESTAMP}
CSV=$RESULTS_DIR/performance.csv
mkdir -p $RESULTS_DIR

echo "VF3PDL Enron - ACTUALLY WORKING VERSION"
echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,MaxMemory_KB,CPU_Percent,ContextSwitches,PageFaults,Status" > $CSV

for type in sparse dense; do
    for size in 8 16 24 32; do
        for threads in 1 4 8 16 32 48 64; do
            echo "[Test] ${type} ${size}v @ ${threads}t"
            
            # Run WITHOUT timeout wrapper - use time's built-in timeout
            /usr/bin/time -v -o $RESULTS_DIR/time_output.txt \
                bash -c "timeout 90s ~/vf3lib/bin/vf3p \
                    ~/vf3_test_enron_NEW/query_${type}_${size}v_1_NO_LABELS.graph \
                    ~/vf3_test_enron_NEW/enron_NO_LABELS.graph \
                    -a 2 -t $threads -l 0 -h 3" \
                > $RESULTS_DIR/vf3_output.txt 2>&1
            
            # Parse VF3P output
            result=$(cat $RESULTS_DIR/vf3_output.txt | grep -E "^[0-9]+ [0-9\.]+ [0-9\.]+" | head -1)
            if [ -n "$result" ]; then
                sol=$(echo "$result" | awk '{print $1}')
                first=$(echo "$result" | awk '{print $2}')
                total=$(echo "$result" | awk '{print $3}')
                status="OK"
            else
                sol=0; first=0; total=90
                status="TIMEOUT"
            fi
            
            # Parse time metrics (now they'll actually be there!)
            max_mem=$(grep "Maximum resident" $RESULTS_DIR/time_output.txt | awk '{print $6}')
            cpu=$(grep "Percent of CPU" $RESULTS_DIR/time_output.txt | awk '{print $7}' | tr -d '%')
            ctx=$(grep "Voluntary context switches" $RESULTS_DIR/time_output.txt | awk '{print $5}')
            pgf=$(grep "Minor" $RESULTS_DIR/time_output.txt | awk '{print $5}')
            
            echo "$type,$size,$threads,$sol,$first,$total,$max_mem,$cpu,$ctx,$pgf,$status" >> $CSV
            echo "  → $sol solutions, ${max_mem}KB memory, ${cpu}% CPU"
        done
    done
done

echo "✅ DONE! Results: $CSV"
