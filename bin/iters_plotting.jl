using Pkg
Pkg.activate("Optimization")

using Plots
using JSON
using DataFrames, CSV



function main()
    folder = "Optimization/results"
    files = ["Sc1_2200_iters.txt", "Sc2_4000_iters.txt"]
    labels = ["Sc1", "Sc2"]
    colors = [:blue, :red]

    data = []

    for f in files
        push!(data, JSON.parsefile(joinpath(folder, f)))
    end

    plt = plot()
    
    for (d, l, c) in zip(data, labels, colors)
        iter = [a["iter"] for a in d]
        best_obj = [a["best_obj"] for a in d]
        cur_obj = [a["cur_obj"] for a in d]

        first_obj = d[1]["cur_obj"]

        plot!(plt, iter, best_obj ./ first_obj, label=l*"_best", linecolor=c)
        plot!(plt, iter, cur_obj ./ first_obj, label=l*"_cur", linecolor=c, linestyle=:dash)
    end

    plot!(ylabel="Utility Improvement Ratio", xlabel="Iteration")

    display(plt)
end


main()