using DataFrames
using LoopVectorization

#
# Supporitng Function
#
function shortest_paths_from_df(::Type{Tf}, edge_data::DataFrame, n::Ti) where {Ti<:Integer, Tf<:AbstractFloat}
    # Uses floyd_warshall alg to compute APSP
    # TODO add speed improvements @inbounds, @simd

    #Int output
    dist = Array{Tf, 2}(undef, (n,n))
    fill!(dist, typemax(Tf))
    # Set edge weights
    for r in eachrow(edge_data)
        dist[r.dst,r.src] = convert(Tf, r.weight) + 1
    end

    floyd_warshall_iterations!(dist, n)
    return dist
end

# function ttest(::Type{T}, n<:Integer) where T<:AbstractFloat
#     a = Array{T,2}(undef, (n,n))
#     fill!(a, zero(T))
#     return a
# end


"""
    floyd_warshall_iterations!(dist_matrix)

Zeros the main diagal and exicutes the floyd_warshall APAP iterations in place. 
"""
function floyd_warshall_iterations!(dist::Matrix{Tf}, n::Ti) where {Ti<:Integer, Tf<:AbstractFloat}
    # Zero diag
    for i in 1:n
        dist[i,i] = zero(Tf)
    end

    # Main loops
    for k in 1:n
        for i in 1:n
            for j in 1:n
                if dist[j,i] > dist[k,i] + dist[j,k]
                    dist[j,i] = dist[k,i] + dist[j,k]
                end
            end
        end
    end
end

#
# Functions to compute objective value
#

function potential_func(dist::Tf, weight::Tf) where Tf<:AbstractFloat
    return one(Tf)/dist * weight
end

function update_col!(d_c::Matrix{Tf}, M::Vector{Tf}, link_nodes::Vector{Ti}, s::Integer, n::Integer) where {Ti<:Integer, Tf<:AbstractFloat}
    # Initalize local vars
    partial_obj = zero(Tf)
    offset = zero(Tf)
    a = zero(Tf)
    b = zero(Tf)
    n_link = length(link_nodes)
    k = zero(Ti)

    #Update all but last transit node
    #for k in link_nodes[1:end-1] # This causes ~1GiB of heap allocaitons
    for i in 1:n_link-1
        k = link_nodes[i]
        offset = d_c[k,s]
        for d in 1:n
            a = d_c[d,s]
            b = d_c[d,k] + offset  # + accesstime
            d_c[d,s] = (a <= b)*a + (a > b)*b  
        end
    end

    # Update last transit node with delta on objective val
    k = link_nodes[end]
    offset = d_c[k,s]
    for d in 1:n
        a = d_c[d,s]
        b = d_c[d,k] + offset 
        d_c[d,s] = (a <= b)*a + (a > b)*b  
        
        if s != d
            partial_obj += potential_func(d_c[d,s],M[d])
        end 
    end
    return partial_obj
end

function compute_obj(d_w::Matrix{Tf}, M::Vector{Tf}) where Tf<:AbstractFloat
    # Get matrix sizes
    n = size(d_w)[1]

    obj_val = zero(Tf)
    for s in 1:n
        for d in 1:n
            if s != d
                obj_val += potential_func(d_w[d,s], M[d])
            end
        end
    end
    return obj_val
end

function compute_obj(d_w::Matrix{Tf}, M::Vector{Tf}, d_t::Matrix{Tf}, link_nodes::Vector{Ti}, d_c::Matrix{Tf}, offset::Vector{Tf}) where {Ti<:Integer, Tf<:AbstractFloat}
    # Computure shortest paths and compute objective value
    # idxs = findall(d_t[1, 2:end] .!= 0)
    # push!(idxs,1)
    # d_t = d_t[idxs,idxs]
    # link_nodes = link_nodes[idxs]

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

    obj_val = zero(Tf)

    # Update the shortest paths from the transit nodes
    for s in link_nodes
        obj_val += update_col!(d_c, M, link_nodes, s, n)
    end

    #Update remaining nodes
    for s in 1:n
        in(s, link_nodes) && continue
        obj_val += update_col!(d_c, M, link_nodes, s, n)
    end
    return obj_val
end