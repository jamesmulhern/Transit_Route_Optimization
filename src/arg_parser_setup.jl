using ArgParse

opt_settings_cfg = ArgParseSettings()
@add_arg_table! opt_settings_cfg begin
    "--impv_iter_cap"
    help = "Maximum number of iterations to perfrom when looking for first or best improvements"
    arg_type = Int
    default = -1
    "--max_sol_length"
    help = "Maximum length of the solution. Sum of each edge in the solution"
    arg_type = Int
    default = -1
    "--max_sol_size"
    help = "Maximum number of vertexs in the solution vector"
    arg_type = Int
    default = -1
    "--max_comb_length"
    help = "Maximum conbined lenght of the solution. =sum(sol.d) + sol.n * dwell_time"
    arg_type = Int
    default = -1
    "--limit_connections"
    help = "Limits the number of connections in the optimization graph to the k nearest nodes"
    arg_type = Int
    default = -1
    "--dwell_time"
    help = "TU Stopping time at each station in seconds"
    arg_type = Int
    default = 20
    "--waiting_time"
    help = "Rider waiting time in seconds at station before boarding TU. Often set to headway/2"
    arg_type = Int
    default = 300
    "--run_config"
    help = "Select a pre-defined configuration for the neighborhood"
    arg_type = Int
    default = 1
end