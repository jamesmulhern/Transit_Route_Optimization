using Pkg
Pkg.activate("."; io=devnull)

using DataFrames, CSV

include("../src/methods.jl")
include("../src/arg_parser_setup.jl")


function main(argString::Vector{String})

    file = "instances/Winch_Scenario_1.zip"
    parse_settings!([MHLib.all_settings_cfgs..., opt_settings_cfg],Vector{String}())
    # Init problem
    println("Loading Instance")
    inst = OptInstance{Int32, Float32}(file, 500)
    println("Creating Solution Struct")
    sol = OptSolution(inst)
    sol.use_gpu = false

    update_solution_data!(sol)
    println("obj_pre: $(obj(sol))")

    sol.x = [1135,1128,771,1427,1053,652,693,163,266,1340]
    invalidate!(sol)
    println("sol: $(sol.x)")
    println("obj_cpu: $(obj(sol))")

    base = [1135,1128,771,1427,1053,652,693,163,266,1340]
    util = inst.M[inst.links[base]]
    println("base sol: $(base)")
    println("util vals: $(util)")
    for i in 1:10
        new = copy(base)
        deleteat!(new, i)
        sol.x = new
        invalidate!(sol)
        println("\niter: $i")
        println("sol: $(sol.x)")
        println("obj_cpu: $(obj(sol))")
    end
    # sol.use_gpu = true
    # invalidate!(sol)
    # println("obj_gpu: $(obj(sol))")


    # Select Method Configuration
    # alg = GVNS(sol, 
    #         [MHMethod("peak_con", peak_const!, 6)],
    #         [MHMethod("  1shuf", ls_1shuff!, 1), MHMethod("  1swap", ls_1swap!, 2), MHMethod(" insert",ls_insert!, 2)],
    #         [MHMethod("sh_10-3", shaking!, 3)],
    #         consider_initial_sol = true)


    # Run Algortim
    # run!(alg)
    # method_statistics(alg.scheduler)
    # main_results(alg.scheduler)

    return nothing
end

main(ARGS)