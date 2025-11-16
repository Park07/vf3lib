#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/roadNet_FIXED_${TIMESTAMP}
FINAL_CSV=~/vf3lib/results/nov-rerun-vf3p/roadnet_vf3pdl_performance.csv
PERF_CSV=~/vf3lib/results/nov-rerun-vf3p/roadnet_vf3pdl_perf.csv

mkdir -p $RESULTS_DIR

echo "Dataset,Type,Size,Threads,TimeLimit_s,Time_s,Count,Status,MaxMemory_KB,CPU_Percent,ContextSwitches,PageFaults" > $FINAL_CSV

test_count=0
for type in sparse dense; do
    for size in 8 16 24 32; do
        query=~/vf3_test_roadnet/query_${type}_${size}v_1_NO_LABELS.graph
        
        for threads in 1 4 8 16 32 48 64; do
            ((test_count++))
            
            # NO timeout only for dense 48/64
            if [ "$type" = "dense" ] && [ $threads -ge 48 ]; then
                TIMEOUT_VAL=0
                echo "[$test_count/56] ${type} ${size}v @ ${threads}t (NO TIMEOUT)"
                
                # Run WITHOUT timeout, capture output AND time
                /usr/bin/time -v -o ${RESULTS_DIR}/time_${test_count}.txt \
                    ./bin/vf3p $query ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
                      -a 2 -t $threads -l 0 -h 3 > ${RESULTS_DIR}/vf3p_${test_count}.txt 2>&1
            else
                TIMEOUT_VAL=90
                echo "[$test_count/56] ${type} ${size}v @ ${threads}t (90s)"
                
                # Run WITH timeout, capture output AND time
                /usr/bin/time -v -o ${RESULTS_DIR}/time_${test_count}.txt \
                    timeout 90s ./bin/vf3p $query ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
                      -a 2 -t $threads -l 0 -h 3 > ${RESULTS_DIR}/vf3p_${test_count}.txt 2>&1
            fi
            
            # Parse VF3P output: "count first_time total_time [STATUS]"
            vf3p_output=$(tail -1 ${RESULTS_DIR}/vf3p_${test_count}.txt)
            count=$(echo "$vf3p_output" | awk '{print $1}')
            time=$(echo "$vf3p_output" | awk '{print $3}')
            vf3p_status=$(echo "$vf3p_output" | awk '{print $4}')
            
            # Get memory/CPU from time file
            max_mem=$(grep "Maximum resident set size" ${RESULTS_DIR}/time_${test_count}.txt | awk '{print $NF}')
            cpu_percent=$(grep "Percent of CPU" ${RESULTS_DIR}/time_${test_count}.txt | awk '{print $NF}' | tr -d '%')
            ctx_switches=$(grep "Voluntary context switches" ${RESULTS_DIR}/time_${test_count}.txt | awk '{print $NF}')
            page_faults=$(grep "Minor (reclaiming a frame) page faults" ${RESULTS_DIR}/time_${test_count}.txt | awk '{print $NF}')
            
            status="SUCCESS"
            if [ "$vf3p_status" = "TIMEOUT" ]; then
                status="TIMEOUT"
            fi
            
            echo "roadnet,${type},${size},${threads},$TIMEOUT_VAL,$time,$count,$status,$max_mem,$cpu_percent,$ctx_switches,$page_faults" >> $FINAL_CSV
            echo "  → ${count} solutions, ${time}s"
        done
    done
done

echo "Phase 1 complete!"

echo "Algorithm,Type,Size,Threads,Cycles,Instructions,IPC,CacheMisses,BranchMisses,ContextSwitches" > $PERF_CSV

perf_count=0
for type in sparse dense; do
    for size in 8 16 24 32; do
        query=~/vf3_test_roadnet/query_${type}_${size}v_1_NO_LABELS.graph
        for threads in 1 4 8 16 32 48 64; do
            ((perf_count++))
            
            perf stat -e cycles,instructions,cache-misses,branch-misses,context-switches \
                -o ${RESULTS_DIR}/perf_${perf_count}.txt \
                timeout 30s ./bin/vf3p $query ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
                  -a 2 -t $threads -l 0 -h 3 > /dev/null 2>&1
            
            cycles=$(grep -E "^\s*[0-9,]+\s+cycles" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            instructions=$(grep -E "^\s*[0-9,]+\s+instructions" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            cache_misses=$(grep -E "^\s*[0-9,]+\s+cache-misses" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            branch_misses=$(grep -E "^\s*[0-9,]+\s+branch-misses" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            ctx=$(grep -E "^\s*[0-9,]+\s+context-switches" ${RESULTS_DIR}/perf_${perf_count}.txt | awk '{print $1}' | tr -d ',')
            
            ipc=$([ ! -z "$cycles" ] && [ "$cycles" != "0" ] && echo "scale=3; $instructions / $cycles" | bc || echo "N/A")
            
            echo "vf3pdl,${type},${size},${threads},${cycles},${instructions},${ipc},${cache_misses},${branch_misses},${ctx}" >> $PERF_CSV
        done
    done
done

echo "COMPLETE!"
