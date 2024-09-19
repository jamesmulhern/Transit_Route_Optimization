using Pkg
Pkg.activate("Optimization")

using Plots
using JSON
using DataFrames, CSV

include("../src/DataFrameGraph.jl")
include("../src/OptInstanceTools.jl")


function plot_graph!(plt, g::DataFrameGraph; args...)
    for e in eachrow(g.edges)
        src = e.src
        dst = e.dst
        x = g.nodes.x[[src,dst]]
        y = g.nodes.y[[src,dst]]
        plot!(plt, x, y; args...)
    end 
end

function plot_utility!(plt, points::DataFrame)

    x_unq = unique(points.x)
    y_unq = unique(points.y)
    sort!(x_unq, rev=false)
    sort!(y_unq, rev=false)

    mat = fill(NaN, length(y_unq), length(x_unq))

    for (x, y, val) in zip(points.x, points.y, points.utility)
        x_idx = findfirst(x_unq .== x)
        y_idx = findfirst(y_unq .== y)
        mat[y_idx, x_idx] = val
    end

    # Create Color Bar
    c_scale = cgrad(:roma, rev=true, scale=:exp)
    plt = heatmap!(x_unq, y_unq, mat, aspect_ratio=:equal, c=c_scale)
end

function plot_solution!(plt, route::DataFrameGraph, sol::Vector{Any}; args...)
    n = length(sol)

    # Plot Solution
    for i in 1:n
        j = mod(i+1, Base.OneTo(n))

        src = sol[i] 
        dst = sol[j] 

        # src = route.nodes.link_idx[i]
        # dst = route.nodes.link_idx[j]

        x = route.nodes.x[[src,dst]]
        y = route.nodes.y[[src,dst]]
        plot!(plt, x, y, markersize=3, linewidth=2, arrow=true; args...)
    end

end

function best_sol(iters)
    sol = []
    for d in iters
        if d["cur_obj"] == d["best_obj"]
            sol = d["cur_sol"]
        end
    end
    return sol
end

function main()
    inst_file = "InstanceGeneration/data/instances/Winch_Inst_Test.zip"
    sol_iters = "Optimization/results/Sc1_2200_iters.txt"
    util_file = "InstanceGeneration/data/scenarios/Scenario_1_Public_Schools_20000_200_10.csv"

    # inst_file = "InstanceGeneration/data/instances/Winch_Inst_Sc2.zip"
    # sol_iters = "Optimization/results/Sc2_4000_iters.txt"
    # util_file = "InstanceGeneration/data/scenarios/Scenario_2_Schools_Other_20000_150_10.csv"

    # Load Instances
    base, route = read_opt_instance(inst_file)

    # Load Utility Data
    util = DataFrame(CSV.File(util_file))

    # Load Iterations 
    iters = JSON.parsefile(sol_iters)

    plt = plot(legend=false)

    #Plot Utility heatmap
    plot_utility!(plt, util)

    # Plot Baseline Graph
    plot_graph!(plt, base, linecolor=:black) 

    # Plot Solution
    s = best_sol(iters)
    plot_solution!(plt, route, s, linecolor=:red)

    #Set Limits
    plot!(xlimits=(225500, 232500), ylimits=(909000,914000))

    display(plt)

end


main()