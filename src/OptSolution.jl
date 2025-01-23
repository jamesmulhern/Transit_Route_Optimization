using MHLib
using DataFrames, CSV
using CUDA
using NearestNeighbors


#
# Includes
#
include("support_functions.jl")
include("support_functions_gpu.jl")
include("OptInstanceTools.jl")
include("OptLogger.jl")

using .OptLogging

struct OptInstParams{Ti<:Integer, Tf<:AbstractFloat}
    file::String
    headway::Ti
    move_k::Ti
end

struct GraphData{Tf<:AbstractFloat}
    x::Vector{Tf}
    y::Vector{Tf}
    adj::BitMatrix
    kdTree::NearestNeighbors.NNTree
end

#
# MHLib Instance Setup
# 

struct OptInstance{Ti<:Integer, Tf<:AbstractFloat}
    n_w::Ti                 # Number of walk vertices
    n_r::Ti                 # Number of route vertices
    d_w::Matrix{Tf}
    d_r::Matrix{Tf}
    d_c::Matrix{Tf}
    M::Vector{Tf}
    links::Vector{Ti}
    move_k::Ti
    move_mat::Array{Ti,3}
    offset::Vector{Tf}
    gpu_data::Union{GPUDatasets{Tf}, Nothing}
    wg::GraphData{Tf}
    og::GraphData{Tf}
end

function generate_move_mat(d_r::Matrix{Tf}, n_r::Ti, k::Ti) where {Ti<:Integer, Tf<:AbstractFloat}
    # TODO Check if k < n_r-2

    move_mat = Array{Ti, 3}(undef, (n_r,n_r,k))

    for i in 1:n_r, j in 1:n_r
        opts = convert.(Ti, collect(1:n_r))
        rmv = Vector{Ti}()
        for (n,v) in pairs(opts)
            if v == i || v==j
                push!(rmv,n)
            end
        end
        deleteat!(opts, rmv)
        
        dist = [d_r[v,i] + d_r[j,v] for v in opts]
        move_mat[j,i,:] = opts[partialsortperm(dist, 1:k)]
    end
    return move_mat
end


function OptInstance{Ti, Tf}(filename::String, k::Int=-1) where {Ti<:Integer, Tf<:AbstractFloat}
    println("Reading Instance")
    base_g, route_g = read_opt_instance(filename)

    n_w = convert(Ti, nv(base_g))
    n_r = convert(Ti, nv(route_g))

    println("Computing Shortest Path Matrixes")
    d_w = shortest_paths_from_df(Tf, base_g.edges, n_w)
    d_r = shortest_paths_from_df(Tf, route_g.edges, n_r)

    M = convert(Vector{Tf}, base_g.nodes.weight)
    links = convert(Vector{Ti}, route_g.nodes.link_idx)
    offset = convert(Vector{Tf}, route_g.nodes.offset)

    println("Generating graph datas")
    adj_mat = falses(n_w,n_w)
    for row in eachrow(base_g.edges)
        adj_mat[row.dst,row.src] = true
    end

    wg = GraphData{Tf}(base_g.nodes.x, base_g.nodes.y, adj_mat, KDTree(vcat(base_g.nodes.x', base_g.nodes.y')))

    adj_og = trues(n_r,n_r)
    for i in 1:n_r
        adj_og[i,i] = false
    end
    og = GraphData{Tf}(route_g.nodes.x, route_g.nodes.y, adj_og, KDTree(vcat(route_g.nodes.x', route_g.nodes.y')))

    println("Computing Move Matrix")
    k == -1 ? move_k = n_r-2 : move_k = convert(Ti, k)
    move_mat = generate_move_mat(d_r, n_r, move_k)
    
    #access_time = route_g.nodes.offset

    println("Setting up CUDA arrays")
    if CUDA.functional()
        println("Using GPU")
        gpu_data = GPUDatasets(d_w, d_w, M, offset)
    else
        gpu_data = nothing
    end



    inst = OptInstance{Ti,Tf}(n_w, n_r, 
                              d_w, d_r, copy(d_w), 
                              M, links, 
                              move_k, move_mat, 
                              offset, 
                              gpu_data, 
                              wg, og)
    return inst
end

#
# MHLib Solution Setup
#

mutable struct OptSolution{Ti<:Integer, Tf<:AbstractFloat} <: VectorSolution{Ti}
    inst::OptInstance{Ti,Tf}
    obj_val::Tf
    obj_val_valid::Bool
    score::Tf
    n::Ti
    x::Vector{Ti}
    d::Vector{Tf}
    links::Vector{Ti}
    use_gpu::Bool
end

#Define constuctor for inst input
function OptSolution(inst::OptInstance{Ti, Tf}) where {Ti<:Integer, Tf<:AbstractFloat}
    return OptSolution{Ti,Tf}(inst, zero(Tf), false, zero(Tf), zero(Ti), Vector{Ti}(), Vector{Tf}(), Vector{Ti}(), !isnothing(inst.gpu_data))
end

function Base.show(io::IO, inst::OptInstance{Ti, Tf})  where {Ti<:Integer, Tf<:AbstractFloat}
    println(io, "n_w: $(inst.n_w), n_r: $(inst.n_r)")
end

# Set to maximization problem
MHLib.to_maximize(::OptSolution{Ti, Tf})  where {Ti<:Integer, Tf<:AbstractFloat} = true

#
# Copy and Display Functions
#

function Base.copy!(s1::OptSolution{Ti,Tf}, s2::OptSolution{Ti,Tf}) where {Ti<:Integer, Tf<:AbstractFloat}
    s1.inst = s2.inst                           # Copies identifier only
    s1.obj_val = s2.obj_val                     # Copies value
    s1.obj_val_valid = s2.obj_val_valid         # Copies value
    s1.score = s2.score                         # Copies value
    s1.n = s2.n
    copy!(s1.x, s2.x)                           # Duplicates vectors (allocations?)
    copy!(s1.d, s2.d)
    copy!(s1.links, s2.links)
    s1.use_gpu = s2.use_gpu
end

# Does not duplicate the instance, allocates for vectors in solution
Base.copy(s::OptSolution{Ti,Tf}) where {Ti<:Integer, Tf<:AbstractFloat} =
    OptSolution{Ti, Tf}(s.inst, s.obj_val, s.obj_val_valid, s.score, s.n, copy(s.x), copy(s.d), copy(s.links), s.use_gpu)

Base.show(io::IO, s::OptSolution{Ti, Tf}) where {Ti<:Integer, Tf<:AbstractFloat} = 
    print(io, "Obj: $(round(s.obj_val, digits=1)), Score: $(round(s.score, digits=1)), Len: $(round(sum(s.d),digits=1)), n: $(s.n), Val: $(s.x)")


#
# Solution Methods
#
"""
    update_solution_data(opt_solution)

Updates the metadata related to the solution. 
"""
function update_solution_data!(s::OptSolution{Ti, Tf})  where {Ti<:Integer, Tf<:AbstractFloat}
    #Update size
    s.n = length(s.x)
    
    # Get distances from the opt_matrix
    calc_d_and_links!(s)
end

function calc_d_and_links!(s::OptSolution{Ti, Tf}) where {Ti<:Integer, Tf<:AbstractFloat}
    # Get distances from the opt_matrix
    #sol.d = [s.inst.d_r[s.x[mod(i+1, Base.OneTo(s.n))], s.x[i]] for i in 1:s.n]
    s.d = zeros(Tf, s.n)
    for i in 1:s.n
        j = mod(i+1, Base.OneTo(s.n))
        s.d[i] = s.inst.d_r[s.x[j], s.x[i]]
    end
    s.links = s.inst.links[s.x]
end

function generate_t_matrix(s::OptSolution{Ti,Tf}) where {Ti<:Integer, Tf<:AbstractFloat}
    u_links = unique(s.links)
    n = length(u_links)  #Convert?
    
    d_t = Array{Tf, 2}(undef, (n,n))
    fill!(d_t, typemax(Tf)) #fill with Inf of the provided float type

    for i in 1:s.n
        src_idx = findfirst(u_links .== s.links[i])
        dst_idx = findfirst(u_links .== s.links[mod(i+1,Base.OneTo(s.n))])

        d_t[dst_idx, src_idx] = s.d[i]
    end

    floyd_warshall_iterations!(d_t, n)

    return d_t, u_links
end


#
# Custom Methods
#

"""
    initialize!(::OptSolution)

Initialize solution in a meaningful way.
"""
function MHLib.initialize!(sol::OptSolution{Ti, Tf})  where {Ti<:Integer, Tf<:AbstractFloat}
    sol.obj_val = compute_obj(sol.inst.d_w, sol.inst.M)
    sol.obj_val_valid = true
end


"""
    calc_objective(::OptSolution)

(Re-)calculate the objective value of the given solution and return it.
"""
function MHLib.calc_objective(sol::OptSolution{Ti, Tf})  where {Ti<:Integer, Tf<:AbstractFloat}
    
    update_solution_data!(sol)

    if sol.n == 0
        #println("Calcing Obj - Base")
        sol.score = compute_obj(sol.inst.d_w, sol.inst.M) 
    elseif sol.use_gpu == true
        #println("Calcing Obj - GPU")
        d_t, u_links = generate_t_matrix(sol)
        offset = sol.inst.offset[sol.x]
        sol.score = compute_obj_gpu(sol.inst.gpu_data, CuArray{Tf}(d_t), CuArray{Ti}(u_links), CuArray{Tf}(offset))
    else
        #println("Calcing Obj - CPU")
        d_t, u_links = generate_t_matrix(sol)
        sol.score = compute_obj(sol.inst.d_w, sol.inst.M, d_t, u_links, sol.inst.d_c, sol.inst.offset[sol.x])
    end
    sol.obj_val = sol.score - (settings[:dist_factor] * sum(sol.d)) - (settings[:stop_factor] * sol.n)
    sol.obj_val_valid = true
    return sol.obj_val
end


"""
    is_equal(::OptSolution, ::OptSolution)

Return `true` if the two solutions are considered equal and false otherwise.

Only checks if solution vectors are the same to avoid computing the obj value.  
"""
is_equal(s1::OptSolution{Ti, Tf}, s2::OptSolution{Ti, Tf})  where {Ti<:Integer, Tf<:AbstractFloat} = 
    s1.x == s2.x

"""
    is_valid(::OptSolution)

Return `true` if the solution is under the required distance.
"""
function is_valid(s::OptSolution{Ti, Tf})  where {Ti<:Integer, Tf<:AbstractFloat}
    valid = true

    # Check max length
    if settings[:max_sol_length] != -1
        valid = valid && sum(s.d) <= settings[:max_sol_length]
    end

    #Check max size
    if settings[:max_sol_size] != -1
        valid = valid && s.n <= settings[:max_sol_size]
    end

    if settings[:max_comb_length] != -1
        valid = valid && (sum(s.d) + s.n * settings[:dwell_time]) <= settings[:max_comb_length]
    end

    return valid
end

"""
    check(::Solution; ...)

Check validity of solution.

If a problem is encountered, terminate with an error.
The default implementation just re-calculates the objective value.
"""
function MHLib.check(s::OptSolution{Ti, Tf}; kwargs...)::Nothing where {Ti<:Integer, Tf<:AbstractFloat}
    if s.obj_val_valid
        old_obj = s.obj_val
        invalidate!(s)
        if !isapprox(old_obj, obj(s); rtol=10^-4)
            error("Solution has wrong objective value: $old_obj, should be $(obj(s))")
        end
    end
end

function MHLib.Log.get_logger(sol::OptSolution)
    return CustomLogger(settings[:ofile])
end


# """
#     is_better(::OptSolution, ::OptSolution)

# Return `true` if the first solution is better than the second. Modified to FloatingPoint objective values. 
# Ensures that the s1 is not within sqrt(eps) of s2
# """
# function MHLib.is_better(s1::OptSolution{Ti,Tf}, s2::OptSolution{Ti,Tf}) where {Ti<:Integer, Tf<:AbstractFloat}
#     to_maximize(s1) ? obj(s1) > obj(s2) + sqrt(eps(Tf)) : obj(s1) < obj(s2) - sqrt(eps(Tf))
# end