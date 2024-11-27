#!/bin/bash

# Optimization Setup
inst_name="Winch_Scenario_1"
max_iters=-1                # Max iterations to run
max_time=1200               # Max Running Time
print_freq=25               # Logging interval [iterations]
route_opt_time=3000         # Combined Route Length [Seconds]
max_stops=10                # Max number of stops [stops]
dwell_time=20               # Stopping time at each station [s]
waiting_time=300            # Passenger waiting time at station [s]
config=6                    # Method Configuration setting

# Results location
res_folder=results/k_eval
mkdir -p ${res_folder}

# Date String
date=$(date '+%Y%m%dT%H%M%S')

# Iteration and process setup
num_iters=30
num_procs=2
num_jobs="\j"

echo "Running evaluation of k values"
echo ""
for k in 125 250 500 750 1000 1250 1500
do

    for ((i=0; i<$num_iters; i++)); do
        # Limit to num_procs
        while (( ${num_jobs@P} >= $num_procs )); do
            wait -n
        done

        #Compute File Names
        ifile="instances/${inst_name}.zip"
        run_log="${res_folder}/${date}_${inst_name}_${k}_${i}.log"
        iter_log="${res_folder}/${date}_${inst_name}_${k}_${i}.json"

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
        arg_str+=" --limit_connections ${k}"
        arg_str+=" --run_config ${config}"
        arg_str+=" --waiting_time ${waiting_time}"
        arg_str+=" --mh_ttime ${max_time}"

        echo "Running k=${k} - Iteration: $(($i+1))/${num_iters} - Procs:${num_procs}"
        julia bin/gvns.jl ${arg_str} &>> ${run_log} &
    done
    echo ""
done