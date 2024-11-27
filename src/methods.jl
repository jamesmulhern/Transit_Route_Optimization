using Random

include("OptSolution.jl")

#
# Move Types
#
abstract type Move end

struct SwapMove{Ti<:Integer} <: Move
    idx::Ti
    target::Ti
end

struct InsertMove{Ti<:Integer} <: Move
    idx::Ti
    target::Ti
end

struct BulgMove{Ti<:Integer} <: Move
    idx::Ti
    target::Ti
end

struct ShuffleMove{Ti<:Integer} <: Move 
    A_idx::Ti 
    B_idx::Ti 
end

#const MoveTypes = Union{SwapMove{Ti}, InsertMove{Ti}} where {Ti<:Integer}

#
# Move Functions
#

"""
    apply_move!(opt_solution, move)

Applies the provided move to the solution. Checks that no vertexs are repeated.
"""
function apply_move!(s::OptSolution{Ti,Tf}, move::Move) where {Ti<:Integer, Tf<:AbstractFloat}
    # Perform custom modifications
    modify_solution!(s, move)

    # Compute prv and next indexs
    prev_index = mod(move.idx - 1, Base.OneTo(s.n))
    next_index = mod(move.idx + 1, Base.OneTo(s.n))

    # Update target to correct nodes
    s.x[move.idx] = s.inst.move_mat[next_index, prev_index, move.target]

    # Compute distances
    s.d[prev_index] = s.inst.d_r[s.x[move.idx], s.x[prev_index]]
    s.d[move.idx] = s.inst.d_r[s.x[next_index], s.x[move.idx]]

    #Update link_nodes
    s.links[move.idx] = s.inst.links[s.x[move.idx]]

    # #Check no duplicates
    # if s.x[prev_index] == s.x[move.idx] || s.x[move.idx] == s.x[next_index]
    #     return false
    # end

    #Invalidate objective value
    invalidate!(s)
    return true
end

function modify_solution!(s::OptSolution{Ti,Tf}, move::SwapMove{Ti}) where {Ti<:Integer, Tf<:AbstractFloat}
    s.x[move.idx] = move.target
end

function modify_solution!(s::OptSolution{Ti,Tf}, move::InsertMove{Ti}) where {Ti<:Integer, Tf<:AbstractFloat}
    insert!(s.x, move.idx, move.target)
    insert!(s.d, move.idx, zero(Tf))
    insert!(s.links, move.idx, zero(Ti))
    s.n += one(Ti)
end

function apply_move!(s::OptSolution{Ti,Tf}, move::BulgMove{Ti}) where {Ti<:Integer, Tf<:AbstractFloat}
    cur_idx = s.x[move.idx]
    insert!(s.x, move.idx, s.inst.move_mat[cur_idx, cur_idx, move.target])
    insert!(s.x, move.idx, cur_idx)

    #print("m_idx: $(move.idx), m_t:$(move.target), cur_idx:$(cur_idx), node:$(s.inst.move_mat[cur_idx, cur_idx, move.target])")

    update_solution_data!(s)
    invalidate!(s)
    return true
end

function apply_move!(s::OptSolution{Ti,Tf}, move::ShuffleMove{Ti}) where {Ti<:Integer, Tf<:AbstractFloat}
    A_v = s.x[move.A_idx]
    B_v = s.x[move.B_idx]
    s.x[move.A_idx] = B_v
    s.x[move.B_idx] = A_v

    update_solution_data!(s)
    invalidate!(s)
    return true
end

#
# Local Search Framework
#

"""
    local_search!(opt_solution, move_list, step_func)

Performs a local_search on the neighborhood provided by moves. Provided step_function allows for choce between 
best_improvement (:best_impr), first improvement(:first_impr) or random move (:rand_impr).  
"""
function local_search!(s::OptSolution{Ti,Tf}, moves::Vector{M}, step_func::Symbol=:first_impr) where {Ti <: Integer, Tf <: AbstractFloat, M<:Move}

    # Copy solution
    s_mod = copy(s)
    s_org = copy(s)
    found_improve = false

    # Iterate randomly over the moves
    for move in shuffle!(moves)

        # Apply move
        if !apply_move!(s_mod, move)
            copy!(s_mod, s_org)
            continue
        end

        #println(" obj:$(obj(s_mod)), n:$(s_mod.n), d:$(sum(s_mod.d))")

        #Check solution validity
        if !is_valid(s_mod)
            copy!(s_mod, s_org)
            continue
        end

        # Break for random move
        if step_func == :rand_impr
            copy!(s, s_mod) 
            found_improve = true
            return found_improve 
        end

        # Compute objective  #TODO maybe change for an objective heuristic?
        calc_objective(s_mod)

        # Check if solution is better
        if is_better(s_mod, s) && !isapprox(obj(s_mod), obj(s))
        #if is_better(s_mod, s)
            copy!(s,s_mod)
            found_improve = true

            if step_func == :first_impr
                return found_improve 
            end
        end

        # Reset s_mod
        copy!(s_mod, s_org)
    end
    return found_improve
end


#
# Construction Methods
#

"""
    construct!(opt_solution, par, result)

Construct new solution by choseing `par` random nodes.
This should be updated to be more meaningful
"""
function MHLib.Schedulers.construct!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    generate_random_solution!(s, par)
end

function construct2!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    s.x = [3, 7, 11, 15, 19, 23, 27, 31, 35, 39, 43, 47, 43, 39, 35, 31, 27, 23, 19, 15, 11, 7]
    update_solution_data!(s)
    calc_objective(s)
end

function construct3!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    s.x = [901, 398, 1003, 1491, 899,  473]
    update_solution_data!(s)
    calc_objective(s)
end

function peak_const!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    empty!(s.x)
    s.n = 0
    p1 = (minimum(s.inst.og.x), minimum(s.inst.og.y))
    p2 = (maximum(s.inst.og.x), maximum(s.inst.og.y))
    
    i = 1
    dup_count = 0
    while i <= par
        
        canidate, _ = get_rng_peak!(s, p1, p2)

        if isnothing(canidate)
            continue
        end

        if canidate in s.x
            # Repeat with new random node
            i -= 1
            dup_count += 1
            if dup_count > 10
                println("Found existing point 10 times, skipping adding point to solution")
                i += 1
            end
        else
            # Find Stop location nearest to the canidate
            stop_idx = findfirst(s.inst.links .== canidate)
            stop_idx, _ = nn(s.inst.og.kdTree,[s.inst.wg.x[canidate],s.inst.wg.y[canidate]])
            # if isnothing(stop_idx)
            #     error("Walking node is not linked to opt graph")
            # end
            push!(s.x, stop_idx)
            dup_count = 0
        end
        
        i += 1
    end

    update_solution_data!(s)
    calc_objective(s)
end

function rand_point(p1::Tuple{Tf,Tf}, p2::Tuple{Tf,Tf}) where {Tf<:AbstractFloat}
    xRange = p2[1] - p1[1]
    yRange = p2[2] - p1[2]
    x = xRange * rand() + p1[1]
    y = yRange * rand() + p1[2]
    return [x,y]
end

function get_rng_peak!(s::OptSolution{Ti,Tf}, p1::Tuple{Tf,Tf}, p2::Tuple{Tf,Tf}) where {Ti <: Integer, Tf<:AbstractFloat}

    # Choose random point 
    point = rand_point(p1,p2)

    # find nearest point in walk graph
    next_idx, _ = nn(s.inst.wg.kdTree, point)

    # init vars
    cur_idx = 0
    cur_util = zero(Tf)
    best_util = typemax(Tf)

    # loop until found a local max
    while cur_util < best_util
        # Get utility of point
        cur_idx = next_idx
        cur_util = s.inst.M[cur_idx]

        # Find all neighbors to node
        neighbors = findall(s.inst.wg.adj[:,cur_idx])
        if isempty(neighbors)
            return nothing, nothing
        end

        # Get utility of neighbors and find max
        neighbors_util = s.inst.M[neighbors]
        best_util, max_idx = findmax(neighbors_util)
        next_idx = neighbors[max_idx]
    end

    return cur_idx, cur_util
end


function generate_random_solution!(s::OptSolution{Ti,Tf}, n::Int) where {Ti<:Integer, Tf<:AbstractFloat}
    s.n = n
    s.x = rand(1:s.inst.n_r, s.n)  # Convert?
    calc_d_and_links!(s)
    while !is_valid(s)
        println("Invalid Solution - Retrying with n=$(s.n-1)")
        s.n -= 1
        s.x = rand(1:s.inst.n_r, s.n)
        calc_d_and_links!(s)
    end
    calc_objective(s)
end


#
# Heuristic Methods
#


function get_step_func(val::Int)
    options = [:best_impr, :first_impr, :rand_impr]
    if val > length(options)
        error("Not a valid value must be in rang [1:$(length(options))]. Select from step functions: $options")
    end
    return options[val]
end

"""
    ls_1swap!(opt_solution, par, result)

Perform a 1-swap local search.
"""
function ls_1swap!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    step_func = get_step_func(par)
    moves = [SwapMove{Ti}(idx,target) for idx in 1:s.n, target in 1:s.inst.move_k][:]
    result.changed = local_search!(s, moves, step_func)
end

"""
    ls_insert!(opt_solution, par, result)

Perform a 1-insert local search.
"""
function ls_insert!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    step_func = get_step_func(par)
    moves = [InsertMove{Ti}(idx,target) for idx in 1:s.n+1, target in 1:s.inst.move_k][:]
    result.changed = local_search!(s, moves, step_func)
end


function ls_bulg!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    step_func = get_step_func(par)
    moves = [BulgMove{Ti}(idx,target) for target in 1:s.inst.move_k, idx in 1:s.n][:]
    result.changed = local_search!(s, moves, step_func)
end

function ls_1shuff!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    step_func = get_step_func(par)
    moves = [ShuffleMove{Ti}(idx,target) for idx in 1:s.n, target in 1:s.n][:]
    result.changed = local_search!(s, moves, step_func)
end

"""
    shaking!(opt_solution, par, result)

Perform shaking by removing half of the soluiton and making `par` random 1-swap moves
"""
function shaking!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    remove!(s, 30, result)
    for p in 1:par
        moves = [SwapMove{Ti}(idx,target) for idx in 1:s.n, target in 1:s.inst.move_k][:]
        result.changed = local_search!(s, moves, :rand_impr)
    end
end

"""
    remove!(opt_solution, par, result)

Remove 'par' percent of the solution vector
"""
function remove!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    rmv_idx = randsubseq(1:s.n, par/100)
    
    # Check if no nodes removed or all nodes removed
    if isempty(rmv_idx)
        result.changed = false
        return nothing
    end
    if length(rmv_idx) == s.n
        result.changed = false
        return nothing
    end

    # Remove nodes
    deleteat!(s.x, rmv_idx)

    # Remove any repeating nodes
    rmv_idx = Vector{Int}()
    for i in 2:length(s.x)
        if s.x[i-1] == s.x[i]
            push!(rmv_idx, i)
        end
    end
    deleteat!(s.x, rmv_idx)

    # Updated solution data
    update_solution_data!(s)

    # Invalidate and return
    invalidate!(s)
    result.changed = true
    return nothing
end

function rng_peak!(s::OptSolution{Ti,Tf}, par::Int, result::Result) where {Ti<:Integer, Tf<:AbstractFloat}
    modified = false
    for i in 1:par 
        modified = modified || rng_peak_insert!(s, convert(Ti, rand(1:s.n)))
    end

    if modified 
        update_solution_data!(s)
        invalidate!(s)
        result.changed = true
    else
        result.changed = false
    end

    return nothing
end

# Removes a point at idx and insterts a random peak
function rng_peak_insert!(s::OptSolution{Ti,Tf}, idx::Ti) where {Ti<:Integer, Tf<:AbstractFloat}
    
    idx_1 = mod(idx-1, Base.OneTo(s.n))
    idx_2 = mod(idx+1, Base.OneTo(s.n))

    old_vertex = s.x[idx]
    s.x[idx] = 0

    p1 = (s.inst.og.x[idx_1], s.inst.og.y[idx_1])
    p2 = (s.inst.og.x[idx_2], s.inst.og.y[idx_2])

    repeats = 0
    duplicate = true
    new_vertex = old_vertex
    while (repeats < 10) && (duplicate == true)
        w_idx, _ = get_rng_peak!(s, p1, p2)
        if isnothing(w_idx)
            repeats += 1
            continue
        end
        new_vertex, _ = nn(s.inst.og.kdTree, [s.inst.wg.x[w_idx],s.inst.wg.y[w_idx]])
        duplicate = (new_vertex in s.x)
        repeats += 1
    end

    modified = false
    if duplicate == false
        s.x[idx] = new_vertex
        modified = true
    else
        s.x[idx] = old_vertex
        modified = false
    end

    return modified
end

function sol_info(s::OptSolution)
    return "n:$(s.n), dist:$(round(sum(s.d),digits=2))"
end




