#!/bin/bash

# Optimization Setup
inst_name="Winch_Case_Study"
max_iters=1200              # Max iterations to run
print_freq=25               # Logging interval [iterations]
route_opt_time=3000         # Combined Route Length [Seconds]
max_stops=16                # Max number of stops [stops]
dwell_time=20               # Stopping time at each station [s]
config=6                    # Method Configuration setting
lim_connect=1000            # Limit connections to k nearest stops

# Results location
res_folder=results/waiting_time
mkdir -p ${res_folder}

# Date String
date=$(date '+%Y%m%dT%H%M%S')

# Iteration and process setup
num_iters=30
num_procs=8
num_jobs="\j"

echo "Running evaluation of different waiting times"
ech0 ""
for wt in 0 150 300 450 900
do

    for ((i=0; i<$num_iters; i++)); do
        # Limit to num_procs
        while (( ${num_jobs@P} >= $num_procs )); do
            wait -n
        done

        #Compute File Names
        ifile="instances/${inst_name}.zip"
        run_log="${res_folder}/${date}_${inst_name}_${wt}_${i}.log"
        iter_log="${res_folder}/${date}_${inst_name}_${wt}_${i}.json"

        # Generate arg_string
        arg_str=""
        arg_str+=" --ifile ${ifile}"
        arg_str+=" --ofile ${iter_log}"
        arg_str+=" --mh_titer ${max_iters}"
        arg_str+=" --mh_lfreq ${print_freq}"
        arg_str+=" --max_sol_length ${route_opt_time}"
        arg_str+=" --max_sol_size ${max_stops}"
        arg_str+=" --dwell_time ${dwell_time}"
        arg_str+=" --max_comb_length ${route_opt_time}"
        arg_str+=" --limit_connections ${lim_connect}"
        arg_str+=" --run_config ${config}"
        arg_str+=" --waiting_time ${wt}"
        arg_str+=" --dist_factor 0.0"
        arg_str+=" --stop_factor 0.0"

        echo "$(date '+%Y%m%dT%H%M%S'): Running waiting_time=${wt} - Iteration: $(($i+1))/${num_iters} - Procs:${num_procs}"
        julia bin/gvns.jl ${arg_str} &>> ${run_log} &
    done
    echo ""
done
