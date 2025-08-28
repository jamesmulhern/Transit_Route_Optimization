using Pkg
Pkg.activate("."; io=devnull)

using DataFrames, CSV

include("../src/methods.jl")
include("../src/arg_parser_setup.jl")

function compute_obj_slow(d_w::Matrix{Float32}, M::Vector{Float32}, d_t::Matrix{Float32}, link_nodes::Vector{Int32}, d_c::Matrix{Float32}, offset::Vector{Float32})
    # Get matrix sizes
    n = size(d_w)[1]
    t = size(d_t)[1]

    # Get sub-set of walking distances
    copy!(d_c,d_w)

    # Write in transit distances
    # Write d_t into d_c matrix
    for s in 1:t
        for d in 1:t
            d_c[link_nodes[d],link_nodes[s]] = d_t[d,s] + offset[s] + offset[s] + settings[:waiting_time]
        end
    end

    obj_val = zero(Float32)

    #floyd_warshall
    #@time "floyd_warshall" floyd_warshall_iterations!(d_c, n)
    for d in 1:n
        for s in link_nodes
            for k in link_nodes
                d_c[d,s] = min(d_c[d,s], d_c[k,s] + d_c[d,k])
            end
        end
    end

    for d in 1:n
        for s in 1:n
            for k in link_nodes
                d_c[d,s] = min(d_c[d,s], d_c[k,s] + d_c[d,k])
            end
        end
    end

    # Compute obj
    for s in 1:n 
        for d in 1:n
            if s != d
                obj_val +=  M[d] / d_c[d,s]
            end
        end
    end
    return obj_val
end


function main()
    inst_name="Winch_Scenario_1"

    file = "instances/Winch_Scenario_1.zip"
    parse_settings!([MHLib.all_settings_cfgs..., opt_settings_cfg], Vector{String}())
    # Init problem
    println("Loading Instance")
    inst = OptInstance{Int32, Float32}(file, 500)
    println("Creating Solution Struct")
    sol = OptSolution(inst)
    initialize!(sol)
    generate_random_solution!(sol, 10)

    println("Starting Benchmarking")
    iters = 1000
    calc_objective(sol)
    d_t, u_links = generate_t_matrix(sol)
    offset = sol.inst.offset[sol.x]
    compute_obj(sol.inst.d_w, sol.inst.M, d_t, u_links, sol.inst.d_c, sol.inst.offset[sol.x])
    compute_obj_gpu(sol.inst.gpu_data, CuArray{Float32}(d_t), CuArray{Int32}(u_links), CuArray{Float32}(offset))
    compute_obj_slow(sol.inst.d_w, sol.inst.M, d_t, u_links, sol.inst.d_c, sol.inst.offset[sol.x])

    println("Starting iterations")
    @time "CPU" for _ in 1:iters
        sol.score = compute_obj(sol.inst.d_w, sol.inst.M, d_t, u_links, sol.inst.d_c, sol.inst.offset[sol.x])
        #calc_objective(sol)
    end
    println(sol.score)

    @time "GPU" for _ in 1:iters
        sol.score = compute_obj_gpu(sol.inst.gpu_data, CuArray{Float32}(d_t), CuArray{Int32}(u_links), CuArray{Float32}(offset))
        #calc_objective(sol)
    end
    println(sol.score)

    @time "CPU_slow" for _ in 1:iters
        sol.score = compute_obj_slow(sol.inst.d_w, sol.inst.M, d_t, u_links, sol.inst.d_c, sol.inst.offset[sol.x])
        #calc_objective(sol)
    end
    println(sol.score)


    
end

main()