#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/ENRON_FULL_PERF_${TIMESTAMP}
CSV=$RESULTS_DIR/enron_vf3pdl_performance.csv
PERF_CSV=$RESULTS_DIR/enron_vf3pdl_perf.csv

mkdir -p $RESULTS_DIR

echo "VF3PDL Enron - FULL PERFORMANCE ANALYSIS" | tee $RESULTS_DIR/summary.txt
echo "================================" | tee -a $RESULTS_DIR/summary.txt
echo "Phase 1: Memory & CPU metrics (56 tests)" | tee -a $RESULTS_DIR/summary.txt
echo "Phase 2: Perf hardware counters (56 tests)" | tee -a $RESULTS_DIR/summary.txt
echo "Started: $(date)" | tee -a $RESULTS_DIR/summary.txt

# Phase 1: Memory and CPU tracking
echo "Type,Size,Threads,Solutions,FirstTime_s,TotalTime_s,MaxMemory_MB,AvgMemory_MB,CPU_Percent,ContextSwitches,PageFaults,Status" > $CSV

echo -e "\n=== PHASE 1: Memory & CPU Analysis ===" | tee -a $RESULTS_DIR/summary.txt

for type in sparse dense; do
    for size in 8 16 24 32; do
        for threads in 1 4 8 16 32 48 64; do
            query=~/vf3_test_enron_NEW/query_${type}_${size}v_1_NO_LABELS.graph
            data=~/vf3_test_enron_NEW/enron_NO_LABELS.graph
            
            echo "[Memory] ${type} ${size}v @ ${threads}t"
            
            # Run with time -v for memory tracking
            timeout 90s /usr/bin/time -v ~/vf3lib/bin/vf3p \
                $query $data -a 2 -t $threads -l 0 -h 3 \
                > $RESULTS_DIR/temp_out.txt 2> $RESULTS_DIR/temp_err.txt
            
            exit_code=$?
            
            # Parse VF3P output
            if [[ $exit_code -eq 124 ]]; then
                status="TIMEOUT"
                sol=0; first=0; total=90
            else
                result=$(cat $RESULTS_DIR/temp_out.txt | grep -E "^[0-9]+ [0-9\.]+ [0-9\.]+$")
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
            
            # Parse memory metrics from time -v
            max_mem=$(grep "Maximum resident" $RESULTS_DIR/temp_err.txt | awk '{print $6}')
            avg_mem=$(grep "Average resident" $RESULTS_DIR/temp_err.txt | awk '{print $6}')
            cpu=$(grep "Percent of CPU" $RESULTS_DIR/temp_err.txt | awk '{print $7}' | tr -d '%')
            ctx=$(grep "Voluntary context switches" $RESULTS_DIR/temp_err.txt | awk '{print $5}')
            pgf=$(grep "Page faults" $RESULTS_DIR/temp_err.txt | grep -v "Minor" | awk '{print $4}')
            
            # Convert KB to MB
            max_mem_mb=$((max_mem / 1024))
            avg_mem_mb=$((avg_mem / 1024))
            
            echo "$type,$size,$threads,$sol,$first,$total,$max_mem_mb,$avg_mem_mb,$cpu,$ctx,$pgf,$status" >> $CSV
        done
    done
done

# Phase 2: Perf profiling
echo -e "\n=== PHASE 2: Hardware Counter Analysis ===" | tee -a $RESULTS_DIR/summary.txt
echo "Type,Size,Threads,CacheMisses,CacheReferences,BranchMisses,BranchInstructions,PageFaults,CPUCycles,Instructions,IPC" > $PERF_CSV

for type in sparse dense; do
    for size in 8 16 24 32; do
        for threads in 1 4 8 16 32 48 64; do
            query=~/vf3_test_enron_NEW/query_${type}_${size}v_1_NO_LABELS.graph
            data=~/vf3_test_enron_NEW/enron_NO_LABELS.graph
            
            echo "[Perf] ${type} ${size}v @ ${threads}t"
            
            timeout 90s perf stat -e cache-misses,cache-references,branch-misses,branches,page-faults,cpu-cycles,instructions \
                ~/vf3lib/bin/vf3p $query $data -a 2 -t $threads -l 0 -h 3 \
                > /dev/null 2> $RESULTS_DIR/perf_temp.txt
            
            # Parse perf output
            cache_miss=$(grep "cache-misses" $RESULTS_DIR/perf_temp.txt | awk '{print $1}' | tr -d ',')
            cache_ref=$(grep "cache-references" $RESULTS_DIR/perf_temp.txt | awk '{print $1}' | tr -d ',')
            branch_miss=$(grep "branch-misses" $RESULTS_DIR/perf_temp.txt | awk '{print $1}' | tr -d ',')
            branches=$(grep "branches" $RESULTS_DIR/perf_temp.txt | awk '{print $1}' | tr -d ',')
            pgfaults=$(grep "page-faults" $RESULTS_DIR/perf_temp.txt | awk '{print $1}' | tr -d ',')
            cycles=$(grep "cpu-cycles" $RESULTS_DIR/perf_temp.txt | awk '{print $1}' | tr -d ',')
            instr=$(grep "instructions" $RESULTS_DIR/perf_temp.txt | awk '{print $1}' | tr -d ',')
            
            # Calculate IPC
            if [ -n "$cycles" ] && [ "$cycles" != "0" ]; then
                ipc=$(echo "scale=3; $instr / $cycles" | bc)
            else
                ipc=0
            fi
            
            echo "$type,$size,$threads,$cache_miss,$cache_ref,$branch_miss,$branches,$pgfaults,$cycles,$instr,$ipc" >> $PERF_CSV
        done
    done
done

echo -e "\n✅ COMPLETE!" | tee -a $RESULTS_DIR/summary.txt
echo "Performance CSV: $CSV" | tee -a $RESULTS_DIR/summary.txt
echo "Perf CSV: $PERF_CSV" | tee -a $RESULTS_DIR/summary.txt
