#!/bin/bash

# Setup
inst_name="Winch_Scenario_1"
max_iters=1000                # Mat iterations to run
print_freq=1                # Logging interval [iterations]
route_opt_time=3000         # Combined Route Length [Seconds]
max_stops=10                 # Max number of stops [stops]
dwell_time=20               # Stopping time at each station [s]
waiting_time=300            # Passenger waiting time at station [s]
config=6                    # Method Configuration setting
lim_connect=1500            # Limit connections to k nearest stops


#Compute File Names
date=$(date '+%Y%m%dT%H%M%S')
ifile="instances/${inst_name}.zip"

mkdir -p results
run_log="results/${date}_${inst_name}.log"
iter_log="results/${date}_${inst_name}.json"

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
arg_str+=" --dist_factor 0.0"
arg_str+=" --stop_factor 0.0"


julia bin/gvns.jl ${arg_str} | tee ${run_log}