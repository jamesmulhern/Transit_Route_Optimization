using Pkg
Pkg.activate("."; io=devnull)

using DataFrames, CSV

include("../src/methods.jl")
include("../src/arg_parser_setup.jl")


function main(argString::Vector{String})

    # Set a default iteration values
    settings_new_default_value!(MHLib.Schedulers.settings_cfg, "mh_titer", 10)
    settings_new_default_value!(MHLib.Schedulers.settings_cfg, "mh_lfreq", 1)

    # Parse Settings
    parse_settings!([MHLib.all_settings_cfgs..., opt_settings_cfg], argString)
    println(get_settings_as_string())

    # Init problem
    inst = OptInstance{Int32, Float32}(settings[:ifile], settings[:limit_connections])
    sol = OptSolution(inst)
    initialize!(sol)

    # Select Method Configuration
    if settings[:run_config] == 1
        alg = GVNS(sol, 
                [MHMethod("rng_con", construct!, div(settings[:max_sol_size], 4))],
                [MHMethod("  bulg1", ls_bulg!, 1), MHMethod(" insert",ls_insert!, 1)],
                [MHMethod("sh_10-3", shaking!, 3)],
                consider_initial_sol = true)
    elseif settings[:run_config] == 2
        alg = GVNS(sol, 
                [MHMethod("rng_con", construct!, div(settings[:max_sol_size], 4))],
                [MHMethod("   swap", ls_1swap!, 1), MHMethod("  bulg1", ls_bulg!, 1), MHMethod(" insert",ls_insert!, 1)],
                [MHMethod("sh_10-3", shaking!, 3)],
                consider_initial_sol = true)
    elseif settings[:run_config] == 3
        alg = GVNS(sol, 
                [MHMethod("rng_con", construct!, div(settings[:max_sol_size], 4))],
                [MHMethod(" insert",ls_insert!, 2), MHMethod("  1swap", ls_1swap!, 2)],
                [MHMethod("sh_10-3", shaking!, 3)],
                consider_initial_sol = true)
    elseif settings[:run_config] == 4
        alg = GVNS(sol, 
                [MHMethod("rng_con", construct!, div(settings[:max_sol_size], 4))],
                [MHMethod("  1swap", ls_1swap!, 2), MHMethod(" insert",ls_insert!, 1)],
                [MHMethod("rng_con", construct!, div(settings[:max_sol_size], 4))],
                consider_initial_sol = true)
    else
        error("Not a valid run configuration")
    end


    # Run Algortim
    run!(alg)
    method_statistics(alg.scheduler)
    main_results(alg.scheduler)

    return nothing
end

main(ARGS)