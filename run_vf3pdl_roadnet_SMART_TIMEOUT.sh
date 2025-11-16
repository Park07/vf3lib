#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/roadNet_SMART_${TIMESTAMP}
FINAL_CSV=~/vf3lib/results/nov-rerun-vf3p/roadnet_vf3pdl_performance.csv
PERF_CSV=~/vf3lib/results/nov-rerun-vf3p/roadnet_vf3pdl_perf.csv

mkdir -p $RESULTS_DIR

echo "════════════════════════════════════════════════════"
echo "VF3PDL roadNet - Smart Timeout Strategy"
echo "════════════════════════════════════════════════════"
echo "Threads 1,4,8,16,32: 90s timeout"
echo "Threads 48,64: NO timeout (complete enumeration)"
echo "56 memory tests + 56 perf tests = 112 total"
echo ""

# Phase 1: Memory & CPU
echo "Dataset,Type,Size,Threads,TimeLimit_s,Time_s,Count,Status,MaxMemory_KB,CPU_Percent,ContextSwitches,PageFaults" > $FINAL_CSV

test_count=0
for type in sparse dense; do
    for size in 8 16 24 32; do
        query=~/vf3_test_roadnet/query_${type}_${size}v_1_NO_LABELS.graph
        
        for threads in 1 4 8 16 32 48 64; do
            ((test_count++))
            
            # Smart timeout: 48 and 64 get no timeout
            if [ $threads -ge 48 ]; then
                TIMEOUT_CMD=""
                TIMEOUT_VAL=0
                echo "[$test_count/56] ${type} ${size}v @ ${threads}t (NO TIMEOUT)"
            else
                TIMEOUT_CMD="timeout 90s"
                TIMEOUT_VAL=90
                echo "[$test_count/56] ${type} ${size}v @ ${threads}t (90s timeout)"
            fi
            
            start=$(date +%s.%N)
            /usr/bin/time -v -o ${RESULTS_DIR}/time_${test_count}.txt \
                $TIMEOUT_CMD ./bin/vf3p \
                  $query \
                  ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
                  -a 2 -t $threads -l 0 -h 3 2>&1 > /dev/null
            exit_code=$?
            end=$(date +%s.%N)
            
            time=$(echo "$end - $start" | bc)
            
            # Get count from VF3P output
            result=$(grep -E "^[0-9]+" ${RESULTS_DIR}/time_${test_count}.txt 2>/dev/null | tail -1 | awk '{print $1}')
            count=${result:-0}
            
            max_mem=$(grep "Maximum resident set size" ${RESULTS_DIR}/time_${test_count}.txt | awk '{print $NF}')
            cpu_percent=$(grep "Percent of CPU" ${RESULTS_DIR}/time_${test_count}.txt | awk '{print $NF}' | tr -d '%')
            ctx_switches=$(grep "Voluntary context switches" ${RESULTS_DIR}/time_${test_count}.txt | awk '{print $NF}')
            page_faults=$(grep "Minor (reclaiming a frame) page faults" ${RESULTS_DIR}/time_${test_count}.txt | awk '{print $NF}')
            
            if [ $exit_code -eq 124 ] || (( $(echo "$time >= $TIMEOUT_VAL" | bc -l) )) && [ $TIMEOUT_VAL -gt 0 ]; then
                status="TIMEOUT"
            else
                status="SUCCESS"
            fi
            
            echo "roadnet,${type},${size},${threads},$TIMEOUT_VAL,$time,$count,$status,$max_mem,$cpu_percent,$ctx_switches,$page_faults" >> $FINAL_CSV
            echo "  → ${count} solutions, ${time}s"
        done
    done
done

echo ""
echo "Phase 1 complete! ✓"
echo ""

# Phase 2: Perf profiling (all with 30s for consistency)
echo "Algorithm,Type,Size,Threads,Cycles,Instructions,IPC,CacheMisses,BranchMisses,ContextSwitches" > $PERF_CSV

perf_count=0
for type in sparse dense; do
    for size in 8 16 24 32; do
        query=~/vf3_test_roadnet/query_${type}_${size}v_1_NO_LABELS.graph
        
        for threads in 1 4 8 16 32 48 64; do
            ((perf_count++))
            echo "[$perf_count/56] Profiling: ${type} ${size}v @ ${threads}t"
            
            perf stat -e cycles,instructions,cache-misses,branch-misses,context-switches \
                -o ${RESULTS_DIR}/perf_${perf_count}.txt \
                timeout 30s ./bin/vf3p \
                  $query \
                  ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
                  -a 2 -t $threads -l 0 -h 3 2>&1 > /dev/null
            
            cycles=$(grep -E "^\s*[0-9,]+\s+cycles" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            instructions=$(grep -E "^\s*[0-9,]+\s+instructions" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            cache_misses=$(grep -E "^\s*[0-9,]+\s+cache-misses" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            branch_misses=$(grep -E "^\s*[0-9,]+\s+branch-misses" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            ctx=$(grep -E "^\s*[0-9,]+\s+context-switches" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            
            if [ ! -z "$cycles" ] && [ ! -z "$instructions" ] && [ "$cycles" != "0" ]; then
                ipc=$(echo "scale=3; $instructions / $cycles" | bc)
            else
                ipc="N/A"
            fi
            
            echo "vf3pdl,${type},${size},${threads},${cycles},${instructions},${ipc},${cache_misses},${branch_misses},${ctx}" >> $PERF_CSV
            echo "  → IPC: ${ipc}"
        done
    done
done

echo ""
echo "════════════════════════════════════════════════════"
echo "COMPLETE! ✓"
echo "════════════════════════════════════════════════════"
