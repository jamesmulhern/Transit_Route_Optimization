#!/bin/bash

# Optimization Setup
inst_name="Winch_Scenario_1"
max_iters=1000               # Max iterations to run
print_freq=25               # Logging interval [iterations]
route_opt_time=3000         # Combined Route Length [Seconds]
max_stops=50                # Max number of stops [stops]
dwell_time=20               # Stopping time at each station [s]
waiting_time=300            # Passenger waiting time at station [s]
lim_connect=50              # Limit connections to k nearest stops
config=1


# Results location
res_folder=results/penalty_eval
mkdir -p ${res_folder}

# Date String
date=$(date '+%Y%m%dT%H%M%S')

# Iteration and process setup
num_iters=4
num_procs=1
num_jobs="\j"

echo "Running testing penalty terms"
ech0 ""
for stop_f in 100 200 400
do
    for dist_f in 1.0 2.0 4.0
    do

        for ((i=0; i<$num_iters; i++)); do
            # Limit to num_procs
            while (( ${num_jobs@P} >= $num_procs )); do
                wait -n
            done

            #Compute File Names
            ifile="instances/${inst_name}.zip"
            run_log="${res_folder}/${date}_${inst_name}_${stop_f}_${dist_f}_${i}.log"
            iter_log="${res_folder}/${date}_${inst_name}_${stop_f}_${dist_f}_${i}.json"

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
            arg_str+=" --waiting_time ${waiting_time}"
            arg_str+=" --dist_factor ${dist_f}"
            arg_str+=" --stop_factor ${stop_f}"

            echo -e "\r\033[1A\033[0KRunning dist_f:${dist_f}, stop_f:${stop_f} - Iteration: $(($i+1))/${num_iters} - Procs:${num_procs}"
            julia bin/gvns.jl ${arg_str} &>> ${run_log} &
        done
        echo ""
    done
done