#!/bin/bash

# Optimization Setup
inst_name="Winch_Scenario_1"
max_iters=2000              # Max iterations to run
max_time=1200               # Max Running Time
print_freq=1                # Logging interval [iterations]
route_opt_time=2000         # Combined Route Length [Seconds]
max_stops=20                # Max number of stops [stops]
dwell_time=20               # Stopping time at each station [s]
waiting_time=300            # Passenger waiting time at station [s]
lim_connect=1000              # Limit connections to k nearest stops
config=6


# Results location
res_folder=results/penalty_eval
mkdir -p ${res_folder}

# Date String
date=$(date '+%Y%m%dT%H%M%S')

# Iteration and process setup
num_iters=30
num_procs=2
num_jobs="\j"

echo "Running testing penalty terms"
echo ""

for ((i=0; i<$num_iters; i++))
do
    for stop_f in 50 100 150 200 300 400
    do
        # Limit to num_procs
        while (( ${num_jobs@P} >= $num_procs )); do
            wait -n
        done

        dist_f=0.0

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

        echo "Running dist_f:${dist_f}, stop_f:${stop_f} - Iteration: $(($i+1))/${num_iters} - Procs:${num_procs}"
        julia bin/gvns.jl ${arg_str} &>> ${run_log} &

    done

    for dist_f in 0.5 1.0 1.5 2.0 3.0 4.0
    do
        # Limit to num_procs
        while (( ${num_jobs@P} >= $num_procs )); do
            wait -n
        done

        stop_f=0.0

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

        echo "Running dist_f:${dist_f}, stop_f:${stop_f} - Iteration: $(($i+1))/${num_iters} - Procs:${num_procs}"
        julia bin/gvns.jl ${arg_str} &>> ${run_log} &
    done
done
