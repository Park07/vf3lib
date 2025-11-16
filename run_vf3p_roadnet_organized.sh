#!/bin/bash
cd ~/vf3lib

# Create timestamped results directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DATASET="roadNet-CA"
RESULTS_DIR=~/vf3lib/results/nov-rerun-vf3p/${DATASET}_${TIMESTAMP}
mkdir -p $RESULTS_DIR

SUMMARY_FILE=${RESULTS_DIR}/summary.txt
DETAILED_LOG=${RESULTS_DIR}/detailed_log.txt

# Header
echo "VF3P Experimental Results" | tee $SUMMARY_FILE
echo "=========================" | tee -a $SUMMARY_FILE
echo "Dataset: $DATASET" | tee -a $SUMMARY_FILE
echo "Started: $(date)" | tee -a $SUMMARY_FILE
echo "Data Graph: ~/vf3_test_roadnet/${DATASET}_NO_LABELS.graph" | tee -a $SUMMARY_FILE
echo "" | tee -a $SUMMARY_FILE

for threads in 16 32 48 64; do
    for size in 8 16 24 32; do
        query=~/vf3_test_roadnet/query_sparse_${size}v_1_NO_LABELS.graph
        
        if [ -f "$query" ]; then
            echo "" | tee -a $SUMMARY_FILE
            echo "=== Query: ${size}v sparse, Threads: ${threads} ===" | tee -a $SUMMARY_FILE
            echo "Query file: $query" | tee -a $SUMMARY_FILE
            echo "Start time: $(date +%H:%M:%S)" | tee -a $SUMMARY_FILE
            
            # Run with timeout and save individual result
            RESULT_FILE=${RESULTS_DIR}/result_${size}v_t${threads}.txt
            timeout 300s ./bin/vf3p \
              $query \
              ~/vf3_test_roadnet/roadNet-CA_NO_LABELS.graph \
              -a 2 -t $threads -l 8 -h 3 2>&1 | tee $RESULT_FILE | tee -a $SUMMARY_FILE
            
            echo "End time: $(date +%H:%M:%S)" | tee -a $SUMMARY_FILE
        fi
    done
done

echo "" | tee -a $SUMMARY_FILE
echo "Completed: $(date)" | tee -a $SUMMARY_FILE
echo "All results saved to: $RESULTS_DIR" | tee -a $SUMMARY_FILE

# Create a quick summary CSV
echo "Query,Threads,Solutions,FirstTime,TotalTime,Status" > ${RESULTS_DIR}/results.csv
for result_file in ${RESULTS_DIR}/result_*.txt; do
    if [ -f "$result_file" ]; then
        filename=$(basename $result_file)
        # Parse filename: result_8v_t16.txt
        size=$(echo $filename | grep -oP '\d+v' | grep -oP '\d+')
        threads=$(echo $filename | grep -oP 't\d+' | grep -oP '\d+')
        
        # Parse result line
        result=$(cat $result_file | tail -1)
        echo "${size}v,$threads,$result" >> ${RESULTS_DIR}/results.csv
    fi
done

echo "CSV summary created: ${RESULTS_DIR}/results.csv"
