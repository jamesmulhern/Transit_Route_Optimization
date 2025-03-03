#!/bin/bash

# Setup
inst_name="Winch_Case_Study"
max_iters=1500              # Max iterations to run
max_time=900
print_freq=25               # Logging interval [iterations]
route_opt_time=2000         # Combined Route Length [Seconds]
max_stops=10                # Max number of stops [stops]
dwell_time=20               # Stopping time at each station [s]
waiting_time=300            # Passenger waiting time at station [s]
config=6                    # Method Configuration setting
lim_connect=1000              # Limit connections to k nearest stops

# Create results folder
res_folder=results/proc_eval
mkdir -p ${res_folder}

# Get Datestring
date=$(date '+%Y%m%dT%H%M%S')

num_jobs="\j"
num_iters=32
# Loop over differnt number of processors
for num_procs in 1 2 3 4 8 12 16 # Ensure max < # processors
do
    echo Starting test with ${num_procs} processors

    for ((i=0; i<$num_iters; i++))
    do
        # Limit to num_procs
        while (( ${num_jobs@P} >= $num_procs )); do
            wait -n
        done

        #Compute File Names
        ifile="instances/${inst_name}.zip"
        run_log="${res_folder}/${date}_${inst_name}_${i}_${num_procs}.log"
        iter_log="${res_folder}/${date}_${inst_name}_${i}_${num_procs}.json"

        # Generate arg_string
        arg_str=""
        arg_str+=" --ifile ${ifile}"
        arg_str+=" --ofile ${iter_log}"
        arg_str+=" --mh_titer ${max_iters}"
        arg_str+=" --mh_ttime ${max_time}"
        arg_str+=" --mh_lfreq ${print_freq}"
        arg_str+=" --max_sol_length ${route_opt_time}"
        arg_str+=" --max_sol_size ${max_stops}"
        arg_str+=" --dwell_time ${dwell_time}"
        arg_str+=" --max_comb_length ${route_opt_time}"
        arg_str+=" --limit_connections ${lim_connect}"
        arg_str+=" --run_config ${config}"
        arg_str+=" --waiting_time ${waiting_time}"

        echo "$(date '+%Y%m%dT%H%M%S') Starting processor ${i}/${num_procs}"
        julia bin/gvns.jl ${arg_str} &>> ${run_log} &
    done

    # Wait until all are finished
    while (( ${num_jobs@P} != 0 )); do
        wait -n
    done
done
