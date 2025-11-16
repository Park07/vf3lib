#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/LJ_FULL_PERF_${TIMESTAMP}
FINAL_CSV=~/vf3lib/results/nov-rerun-vf3p/lj_vf3pdl_performance.csv
PERF_CSV=~/vf3lib/results/nov-rerun-vf3p/lj_vf3pdl_perf.csv

mkdir -p $RESULTS_DIR
mkdir -p ~/vf3_test_lj
mkdir -p ~/vf3lib/results/nov-rerun-vf3p

echo "════════════════════════════════════════════════════"
echo "VF3PDL LiveJournal - COMPLETE PERFORMANCE ANALYSIS"
echo "════════════════════════════════════════════════════"
echo "Step 1: Convert LJ data (5 min)"
echo "Step 2: Memory/CPU tests - 56 tests (90 min)"
echo "Step 3: Perf profiling - 56 tests (30 min)"
echo "Total: ~2 hours"
echo ""

# ========================================
# STEP 1: CONVERSION
# ========================================
echo "═══ STEP 1: Converting LJ Data ═══"
cd ~/vf3_test_enron

if [ ! -f ~/vf3_test_lj/livejournal_NO_LABELS.graph ]; then
    echo "Converting data graph..."
    ./convert_to_vf3_no_labels.py \
      ~/thesis_data/raw_datasets/lj/snap.txt \
      ~/vf3_test_lj/livejournal_NO_LABELS.graph
    echo "✓ Data graph converted"
else
    echo "✓ Data graph exists"
fi

for type in dense sparse; do
    for size in 8 16 24 32; do
        src=~/thesis_data/raw_datasets/lj/query_graph_new/${type}/query_${type}_${size}v_1.graph
        dst=~/vf3_test_lj/query_${type}_${size}v_1_NO_LABELS.graph
        
        if [ -f "$src" ] && [ ! -f "$dst" ]; then
            echo "Converting ${type} ${size}v..."
            ./convert_to_vf3_no_labels.py "$src" "$dst"
        fi
    done
done

echo "✓ Conversion complete!"
echo ""

# ========================================
# STEP 2: MEMORY & CPU ANALYSIS
# ========================================
cd ~/vf3lib

echo "Dataset,Type,Size,Threads,TimeLimit_s,Time_s,Count,Status,MaxMemory_KB,CPU_Percent,ContextSwitches,PageFaults" > ${RESULTS_DIR}/memory_cpu.csv
echo "Dataset,Type,Size,Threads,TimeLimit_s,Time_s,Count,Status,MaxMemory_KB,CPU_Percent,ContextSwitches,PageFaults" > ${FINAL_CSV}

echo "═══ STEP 2: Memory & CPU Metrics (56 tests) ═══"
test_count=0

for type in sparse dense; do
    for size in 8 16 24 32; do
        query=~/vf3_test_lj/query_${type}_${size}v_1_NO_LABELS.graph
        
        if [ ! -f "$query" ]; then
            continue
        fi
        
        for threads in 1 4 8 16 32 48 64; do
            ((test_count++))
            echo "[$test_count/56] ${type} ${size}v @ ${threads}t"
            
            rm -f ${RESULTS_DIR}/time_output.txt
            
            start=$(date +%s.%N)
            /usr/bin/time -v -o ${RESULTS_DIR}/time_output.txt \
                timeout 90s ./bin/vf3p \
                  $query \
                  ~/vf3_test_lj/livejournal_NO_LABELS.graph \
                  -a 2 -t $threads -l 0 -h 3 2>&1 > /dev/null
            exit_code=$?
            end=$(date +%s.%N)
            
            time=$(echo "$end - $start" | bc)
            
            # Parse output - VF3P prints: solutions first_time total_time [TIMEOUT]
            result=$(tail -1 ${RESULTS_DIR}/time_output.txt 2>/dev/null | grep -E "^[0-9]")
            if [ ! -z "$result" ]; then
                count=$(echo "$result" | awk '{print $1}')
            else
                count=0
            fi
            
            max_mem=$(grep "Maximum resident set size" ${RESULTS_DIR}/time_output.txt | awk '{print $NF}')
            cpu_percent=$(grep "Percent of CPU" ${RESULTS_DIR}/time_output.txt | awk '{print $NF}' | tr -d '%')
            ctx_switches=$(grep "Voluntary context switches" ${RESULTS_DIR}/time_output.txt | awk '{print $NF}')
            page_faults=$(grep "Minor (reclaiming a frame) page faults" ${RESULTS_DIR}/time_output.txt | awk '{print $NF}')
            
            if [ $exit_code -eq 124 ] || (( $(echo "$time >= 90" | bc -l) )); then
                status="TIMEOUT"
            else
                status="SUCCESS"
            fi
            
            echo "lj,${type},${size},${threads},90,$time,$count,$status,$max_mem,$cpu_percent,$ctx_switches,$page_faults" >> ${RESULTS_DIR}/memory_cpu.csv
            echo "lj,${type},${size},${threads},90,$time,$count,$status,$max_mem,$cpu_percent,$ctx_switches,$page_faults" >> ${FINAL_CSV}
            
            echo "  → ${count} solutions, ${time}s, ${max_mem}KB, ${cpu_percent}% CPU"
        done
    done
done

echo ""
echo "Step 2 complete! ✓"
echo ""

# ========================================
# STEP 3: PERF PROFILING
# ========================================
echo "Algorithm,Type,Size,Threads,Cycles,Instructions,IPC,CacheMisses,BranchMisses,ContextSwitches" > ${RESULTS_DIR}/perf.csv
echo "Algorithm,Type,Size,Threads,Cycles,Instructions,IPC,CacheMisses,BranchMisses,ContextSwitches" > ${PERF_CSV}

echo "═══ STEP 3: Perf Hardware Profiling (56 tests) ═══"
perf_count=0

for type in sparse dense; do
    for size in 8 16 24 32; do
        query=~/vf3_test_lj/query_${type}_${size}v_1_NO_LABELS.graph
        
        if [ ! -f "$query" ]; then
            continue
        fi
        
        for threads in 1 4 8 16 32 48 64; do
            ((perf_count++))
            echo "[$perf_count/56] Profiling: ${type} ${size}v @ ${threads}t"
            
            perf stat -e cycles,instructions,cache-misses,branch-misses,context-switches \
                -o ${RESULTS_DIR}/perf_${type}_${size}v_t${threads}.txt \
                timeout 30s ./bin/vf3p \
                  $query \
                  ~/vf3_test_lj/livejournal_NO_LABELS.graph \
                  -a 2 -t $threads -l 0 -h 3 2>&1 > /dev/null
            
            cycles=$(grep -E "^\s*[0-9,]+\s+cycles" ${RESULTS_DIR}/perf_${type}_${size}v_t${threads}.txt | awk '{print $1}' | tr -d ',')
            instructions=$(grep -E "^\s*[0-9,]+\s+instructions" ${RESULTS_DIR}/perf_${type}_${size}v_t${threads}.txt | awk '{print $1}' | tr -d ',')
            cache_misses=$(grep -E "^\s*[0-9,]+\s+cache-misses" ${RESULTS_DIR}/perf_${type}_${size}v_t${threads}.txt | awk '{print $1}' | tr -d ',')
            branch_misses=$(grep -E "^\s*[0-9,]+\s+branch-misses" ${RESULTS_DIR}/perf_${type}_${size}v_t${threads}.txt | awk '{print $1}' | tr -d ',')
            ctx_switches=$(grep -E "^\s*[0-9,]+\s+context-switches" ${RESULTS_DIR}/perf_${type}_${size}v_t${threads}.txt | awk '{print $1}' | tr -d ',')
            
            if [ ! -z "$cycles" ] && [ ! -z "$instructions" ] && [ "$cycles" != "0" ]; then
                ipc=$(echo "scale=3; $instructions / $cycles" | bc)
            else
                ipc="N/A"
            fi
            
            echo "vf3pdl,${type},${size},${threads},${cycles},${instructions},${ipc},${cache_misses},${branch_misses},${ctx_switches}" >> ${RESULTS_DIR}/perf.csv
            echo "vf3pdl,${type},${size},${threads},${cycles},${instructions},${ipc},${cache_misses},${branch_misses},${ctx_switches}" >> ${PERF_CSV}
            
            echo "  → IPC: ${ipc}, Cache misses: ${cache_misses}"
        done
    done
done

echo ""
echo "════════════════════════════════════════════════════"
echo "VF3PDL LJ ANALYSIS COMPLETE! ✓"
echo "════════════════════════════════════════════════════"
echo ""
echo "Results:"
echo "  • ${FINAL_CSV}"
echo "  • ${PERF_CSV}"
