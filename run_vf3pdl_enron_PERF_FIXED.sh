#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/ENRON_PERF_FIXED_${TIMESTAMP}
CSV=$RESULTS_DIR/enron_vf3pdl_performance.csv
PERF_CSV=$RESULTS_DIR/enron_vf3pdl_perf.csv

mkdir -p $RESULTS_DIR

echo "VF3PDL Enron - FULL PERFORMANCE (FIXED PARSING)" 
echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,MaxMemory_MB,AvgMemory_MB,CPU_Percent,ContextSwitches,PageFaults,Status" > $CSV

echo "=== PHASE 1: Memory & CPU Analysis ==="

for type in sparse dense; do
    for size in 8 16 24 32; do
        for threads in 1 4 8 16 32 48 64; do
            echo "[Memory] ${type} ${size}v @ ${threads}t"
            
            # Run with time -v for memory tracking
            timeout 90s /usr/bin/time -v ~/vf3lib/bin/vf3p \
                ~/vf3_test_enron_NEW/query_${type}_${size}v_1_NO_LABELS.graph \
                ~/vf3_test_enron_NEW/enron_NO_LABELS.graph \
                -a 2 -t $threads -l 0 -h 3 \
                > $RESULTS_DIR/temp_out.txt 2> $RESULTS_DIR/temp_err.txt
            
            exit_code=$?
            
            # Parse VF3P output from STDOUT (temp_out.txt)
            if [[ $exit_code -eq 124 ]]; then
                # Check if there's partial output before timeout
                result=$(cat $RESULTS_DIR/temp_out.txt 2>/dev/null | grep -E "^[0-9]+ [0-9\.]+ [0-9\.]+" | head -1)
                if [ -n "$result" ]; then
                    sol=$(echo "$result" | awk '{print $1}')
                    first=$(echo "$result" | awk '{print $2}')
                    total=$(echo "$result" | awk '{print $3}')
                    status="TIMEOUT_PARTIAL"
                else
                    sol=0; first=0; total=90
                    status="TIMEOUT"
                fi
            else
                result=$(cat $RESULTS_DIR/temp_out.txt | grep -E "^[0-9]+ [0-9\.]+ [0-9\.]+" | head -1)
                if [ -n "$result" ]; then
                    sol=$(echo "$result" | awk '{print $1}')
                    first=$(echo "$result" | awk '{print $2}')
                    total=$(echo "$result" | awk '{print $3}')
                    status="OK"
                else
                    sol=0; first=0; total=0
                    status="ERROR"
                fi
            fi
            
            # Parse memory metrics from time -v (in stderr)
            max_mem=$(grep "Maximum resident" $RESULTS_DIR/temp_err.txt 2>/dev/null | awk '{print $6}')
            avg_mem=$(grep "Average resident" $RESULTS_DIR/temp_err.txt 2>/dev/null | awk '{print $6}') 
            cpu=$(grep "Percent of CPU" $RESULTS_DIR/temp_err.txt 2>/dev/null | awk '{print $7}' | tr -d '%')
            ctx=$(grep "Voluntary context switches" $RESULTS_DIR/temp_err.txt 2>/dev/null | awk '{print $5}')
            pgf=$(grep "Major" $RESULTS_DIR/temp_err.txt 2>/dev/null | awk '{print $5}')
            
            # Convert KB to MB (if values exist)
            if [ -n "$max_mem" ]; then
                max_mem_mb=$((max_mem / 1024))
            else
                max_mem_mb=0
            fi
            
            if [ -n "$avg_mem" ]; then
                avg_mem_mb=$((avg_mem / 1024))
            else  
                avg_mem_mb=0
            fi
            
            echo "$type,$size,$threads,$sol,$first,$total,$max_mem_mb,$avg_mem_mb,$cpu,$ctx,$pgf,$status" >> $CSV
            echo "  → $sol solutions, ${max_mem_mb}MB memory"
        done
    done
done

echo ""
echo "=== PHASE 2: Perf Profiling ==="
echo "Type,Size,Threads,CacheMisses,CacheReferences,BranchMisses,BranchInstructions,PageFaults,CPUCycles,Instructions,IPC" > $PERF_CSV

for type in sparse dense; do
    for size in 8 16 24 32; do
        for threads in 1 4 8 16 32 48 64; do
            echo "[Perf] ${type} ${size}v @ ${threads}t"
            
            timeout 90s perf stat -e cache-misses,cache-references,branch-misses,branches,page-faults,cpu-cycles,instructions \
                ~/vf3lib/bin/vf3p \
                ~/vf3_test_enron_NEW/query_${type}_${size}v_1_NO_LABELS.graph \
                ~/vf3_test_enron_NEW/enron_NO_LABELS.graph \
                -a 2 -t $threads -l 0 -h 3 \
                > /dev/null 2> $RESULTS_DIR/perf_temp.txt
            
            # Parse perf output
            cache_miss=$(grep "cache-misses" $RESULTS_DIR/perf_temp.txt 2>/dev/null | awk '{print $1}' | tr -d ',')
            cache_ref=$(grep "cache-references" $RESULTS_DIR/perf_temp.txt 2>/dev/null | awk '{print $1}' | tr -d ',')
            branch_miss=$(grep "branch-misses" $RESULTS_DIR/perf_temp.txt 2>/dev/null | awk '{print $1}' | tr -d ',')
            branches=$(grep " branches" $RESULTS_DIR/perf_temp.txt 2>/dev/null | awk '{print $1}' | tr -d ',')
            pgfaults=$(grep "page-faults" $RESULTS_DIR/perf_temp.txt 2>/dev/null | awk '{print $1}' | tr -d ',')
            cycles=$(grep "cpu-cycles" $RESULTS_DIR/perf_temp.txt 2>/dev/null | awk '{print $1}' | tr -d ',')
            instr=$(grep " instructions" $RESULTS_DIR/perf_temp.txt 2>/dev/null | awk '{print $1}' | tr -d ',')
            
            # Calculate IPC
            if [ -n "$cycles" ] && [ -n "$instr" ] && [ "$cycles" != "0" ]; then
                ipc=$(echo "scale=3; $instr / $cycles" | bc 2>/dev/null || echo "0")
            else
                ipc=0
            fi
            
            echo "$type,$size,$threads,$cache_miss,$cache_ref,$branch_miss,$branches,$pgfaults,$cycles,$instr,$ipc" >> $PERF_CSV
        done
    done
done

echo "✅ COMPLETE!"
echo "Performance CSV: $CSV"
echo "Perf CSV: $PERF_CSV"
