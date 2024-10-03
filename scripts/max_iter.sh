#!/bin/bash

# Setup
inst_name="Winch_Inst_Test"
max_iters=500 #30000             # Max iterations to run
print_freq=100              # Logging interval [iterations]
route_opt_time=3000         # Combined Route Length [Seconds]
max_stops=50                # Max number of stops [stops]
dwell_time=20               # Stopping time at each station [s]
waiting_time=300            # Passenger waiting time at station [s]
config=1                    # Method Configuration setting
lim_connect=50              # Limit connections to k nearest stops


# #Compute File Names
# date=$(date '+%Y%m%dT%H%M%S')
# ifile="instances/${inst_name}.zip"
# run_log="results/max_iter/${date}_run_${inst_name}.log"
# iter_log="results/max_iter/${date}_iter_${inst_name}.log"

# # Generate arg_string
# arg_str=""
# arg_str+=" --ifile ${ifile}"
# arg_str+=" --ofile ${iter_log}"
# arg_str+=" --mh_titer ${max_iters}"
# arg_str+=" --mh_lfreq ${print_freq}"
# arg_str+=" --max_sol_length ${route_opt_time}"
# arg_str+=" --max_sol_size ${max_stops}"
# arg_str+=" --dwell_time ${dwell_time}"
# arg_str+=" --max_comb_length ${route_opt_time}"
# arg_str+=" --limit_connections ${lim_connect}"
# arg_str+=" --run_config ${config}"


date=$(date '+%Y%m%dT%H%M%S')

#julia -q bin/gvns.jl ${arg_str} > ${run_log}

echo Here
num_procs=6
num_iters=6
num_jobs="\j"  # The prompt escape for number of jobs currently running
for ((i=0; i<$num_iters; i++)); do
    while (( ${num_jobs@P} >= $num_procs )); do
        wait -n
    done
    echo "starting ${i}"

    #Compute File Names
    ifile="instances/${inst_name}.zip"
    run_log="results/max_iter/${date}_run_${inst_name}_${i}.log"
    iter_log="results/max_iter/${date}_iter_${inst_name}_${i}.log"

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

    julia -q bin/gvns.jl ${arg_str} > ${run_log} &
done