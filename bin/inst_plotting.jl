using Pkg
Pkg.activate("Optimization")

using Plots

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

function add_weights!(plt, g::DataFrameGraph)
    w = g.nodes.weight
    scatter!(plt, g.nodes.x, g.nodes.y, marker_z=w, markersize=(w ./ maximum(w)) .* 4 .+ 1)
end


function main()

    # Load Instance 
    #file = "Opt_Testing/opt_data/grid_6_2.zip"
    file = "InstanceGeneration/data/instances/Winch_Inst_Test.zip"
    base, route = read_opt_instance(file)

    plt = plot(legend=false)

    # Plot Walking
    # Plot Baseline Graph
    plot_graph!(plt, base, linecolor=:black) 
    

    # Plot Routes
    #plot_graph!(plt, route, linecolor=:blue)

    # Add weight nodes
    add_weights!(plt, base)
    plot!(xlimits=(225500, 232500), ylimits=(909000,914000))

    display(plt)

end


main()
