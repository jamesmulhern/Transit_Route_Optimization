using Pkg
Pkg.activate("Optimization")

using DataFrames, CSV
using Plots

include("../src/methods.jl")
include("../src/arg_parser_setup.jl")

function plot_graph!(plt, g::DataFrameGraph; args...)
    for e in eachrow(g.edges)
        src = e.src
        dst = e.dst
        x = g.nodes.x[[src,dst]]
        y = g.nodes.y[[src,dst]]
        plot!(plt, x, y; args...)
    end 
end

function add_weights!(plt, g::DataFrameGraph)
    w = g.nodes.weight
    scatter!(plt, g.nodes.x, g.nodes.y, marker_z=w, markersize=(w ./ maximum(w)) .* 4 .+ 1)
end

function plot_solution(s::OptSolution, inst_file::String)

    base, route = read_opt_instance(inst_file)

    plt = plot(legend=false)

    # Plot Baseline Graph
    plot_graph!(plt, base; linecolor=:black)
    #plot_graph!(plt, route; linecolor=:blue)

    # Add heatmap of weight
    add_weights!(plt, base)


    # Plot Solution
    for i in 1:s.n
        j = mod(i+1, Base.OneTo(s.n))

        src = s.links[i]
        dst = s.links[j]

        x = base.nodes.x[[src,dst]]
        y = base.nodes.y[[src,dst]]
        plot!(plt, x, y, linecolor=:red, markersize=3, linewidth=2, arrow=true, xlimits=(225500, 232500), ylimits=(909000,914000))
    end


    display(plt)
end



function main()

    settings_new_default_value!(MHLib.Schedulers.settings_cfg, "mh_titer", 4000)
    settings_new_default_value!(MHLib.Schedulers.settings_cfg, "mh_lfreq", 25)

    argString = String[]
    append!(argString, ["--max_sol_length", "3600"])
    append!(argString, ["--max_sol_size", "50"])
    append!(argString, ["--dwell_time", "45"])
    append!(argString, ["--max_comb_length", "3600"])
    append!(argString, ["--ofile", "log_file_Sc2_2200-3200.txt"])


    parse_settings!([MHLib.all_settings_cfgs..., opt_settings_cfg], argString)
    println(get_settings_as_string())

    #inst = OptInstance(w_n, w_e, r_e, links)
    #file = "case_study_1.zip"
    #file = "Opt_Testing/opt_data/grid_6_2.zip"
    file = "InstanceGeneration/data/instances/Winch_Inst_Sc2.zip"
    inst = OptInstance{Int64, Float64}(file, 50)
    sol = OptSolution(inst)
    initialize!(sol)

    # n = sol.inst.n_r
    # for i in [47], j in 1:n
    #     println("i:$i, j:$j, v:$(sol.inst.move_mat[j,i,:])")
    # end
 
    
    # Set a solution
    #sol.x = [3, 7, 11, 15, 19, 23, 27, 31, 35, 39, 43, 47, 51, 47, 43, 39, 35, 31, 27, 23, 19, 15, 11, 7]
    # Obj = 4850.6
    #sol.x = [3,11,19,27,35,43,51,43,35,27,19,11]
    # Obj = 3704.2
    # sol.x = [115, 116, 117, 118, 119, 118, 117, 116, 115, 114, 113, 126, 139, 152, 165, 178, 204, 191, 178, 165, 152, 139, 126, 113, 100, 87, 74, 61, 48, 35, 48, 61, 74, 87, 100, 113, 112, 111, 110, 109, 108, 106, 107, 108, 109, 110, 111, 112, 113, 114]
    # sol.x = [3, 7, 11, 15, 19, 23, 27, 31, 35, 39, 43, 47, 43, 39, 35, 31, 27, 23, 19, 15, 11, 7]
    # sol.x = [112, 850, 112, 517, 304, 517, 389, 873, 746, 749, 305, 526, 305, 749, 58, 13, 749, 746, 850, 746, 205, 546, 1063, 614, 383, 614, 432, 622, 170]
    # update_solution_data!(sol)
    # calc_objective(sol)
    # println(sol)

    # MHMethod("  bulg1", ls_bulg!, 1), 
    # MHMethod(" insert",ls_insert!, 1),

    alg = GVNS(sol, 
            [MHMethod("rng_con", construct!, 12)],
            #[MHMethod("  bulg1", ls_bulg!, 1), MHMethod("  1swap", ls_1swap!, 1)], 
            [MHMethod("  bulg1", ls_bulg!, 1), MHMethod(" insert",ls_insert!, 1)],
            [MHMethod("sh_10-3", shaking!, 3)], # MHMethod("   rmv", remove!, 25), 
            consider_initial_sol = true)

    run!(alg)
    method_statistics(alg.scheduler)
    main_results(alg.scheduler)

    plot_solution(sol, file)
end

main()