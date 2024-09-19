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

function apply_move!(s::OptSolution{Ti,Tf}, move::BulgMove) where {Ti<:Integer, Tf<:AbstractFloat}
    cur_idx = s.x[move.idx]
    insert!(s.x, move.idx, s.inst.move_mat[cur_idx, cur_idx, move.target])
    insert!(s.x, move.idx, cur_idx)

    #print("m_idx: $(move.idx), m_t:$(move.target), cur_idx:$(cur_idx), node:$(s.inst.move_mat[cur_idx, cur_idx, move.target])")

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
first improvement(:first_impr), random move (:rand_impr) or best_improvement (:best_impr).  
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
        if is_better(s_mod, s)
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

function sol_info(s::OptSolution)
    return "n:$(s.n), dist:$(round(sum(s.d),digits=2))"
end




