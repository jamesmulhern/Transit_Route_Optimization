using CUDA
using LoopVectorization


struct GPUDatasets{Tf<:AbstractFloat}
    d_w::CuArray{Tf, 2, CUDA.DeviceMemory}
    d_c::CuArray{Tf, 2, CUDA.DeviceMemory}
    M::CuArray{Tf, 1, CUDA.DeviceMemory}
    offset::CuArray{Tf, 1, CUDA.DeviceMemory}
end

function GPUDatasets(d_w::Matrix{Tf}, d_c::Matrix{Tf}, M::Vector{Tf}, offset::Vector{Tf}) where {Tf<:AbstractFloat}
    return GPUDatasets{Tf}(CuArray{Tf}(d_w), CuArray{Tf}(d_c), CuArray{Tf}(M), CuArray{Tf}(offset))
end

#
# CUDA Functions
#
function reset_dist!(n::Ti, d_w::CuDeviceMatrix{Tf, 1}, d_c::CuDeviceMatrix{Tf,1}) where {Ti<:Integer, Tf<:AbstractFloat}
    idx = (blockIdx().x-one(Ti)) * blockDim().x + threadIdx().x
    total_threads = gridDim().x * blockDim().x

    i = idx
    while i <= n^2
        @inbounds d_c[i] = d_w[i]
        i += total_threads
    end
    return nothing
end

function write_transit!(t::Ti, waiting_time::Tf, d_c::CuDeviceMatrix{Tf, 1}, d_t::CuDeviceMatrix{Tf, 1}, link_nodes::CuDeviceVector{Ti, 1},  offset::CuDeviceVector{Tf, 1}) where {Ti<:Integer, Tf<:AbstractFloat}
    idx = (blockIdx().x-one(Ti)) * blockDim().x + threadIdx().x
    total_threads = gridDim().x * blockDim().x
    #assume(t > 0)

    i = idx
    while i <= t^2
        s = div(i-one(Ti), t) + one(Ti)
        d = mod(i, Base.OneTo{Ti}(t))
        @inbounds d_c[link_nodes[d],link_nodes[s]] = d_t[d,s] + offset[s] + offset[d] + waiting_time
        i += total_threads
    end
    return nothing
end

function compute_idx(i::Ti, A::Ti) where {Ti<:Integer}
    i = i - one(Ti)
    #assume(A > 0)
    b = convert(Ti, div(i, A))

    a = i - b*A

    b += one(Ti)
    a += one(Ti)
    return a, b 
end

function update_link_nodes!(n::Ti, t::Ti, d_c::CuDeviceMatrix{Tf, 1}, link_nodes::CuDeviceVector{Ti, 1}) where {Ti<:Integer, Tf<:AbstractFloat}
    t_idx = (blockIdx().x - one(Ti)) * blockDim().x + threadIdx().x
    total_threads = gridDim().x * blockDim().x
    a = zero(Tf)
    b = zero(Tf)
    s = zero(Ti)
    d = zero(Ti)
    x = zero(Ti)
    y = zero(Ti)

    # Source Nodes   => link_nodes - length=t 
    # Midpoint Nodes => link_nodes - length=t
    # Destination nodes => All - length=n

    i = t_idx
    @inbounds while i <= (n*t)
        x, y = compute_idx(i, n)
        s = link_nodes[y]
        d = x

        # Get current distance from matrix
        a = d_c[d,s]

        @inbounds for z = 1:t
            k = link_nodes[z]
            b = d_c[k,s] + d_c[d,k]
            a = (a <= b)*a + (a > b)*b # Set a to min(a,b)
        end

        # Write smallest distance into matrix
        d_c[d,s] = a

        # Increase loop counter
        i += total_threads
    end
    return nothing     
end

function update_and_compute!(n::Ti, t::Ti, d_c::CuDeviceMatrix{Tf, 1}, link_nodes::CuDeviceVector{Ti, 1}, M::CuDeviceVector{Tf, 1}, result::CuDeviceVector{Tf, 1}) where {Ti<:Integer, Tf<:AbstractFloat}
    t_idx = (blockIdx().x-one(Ti)) * blockDim().x + threadIdx().x
    total_threads = gridDim().x * blockDim().x
    loc_obj = zero(Tf)
    a = zero(Tf)
    b = zero(Tf)
    s = zero(Ti)
    d = zero(Ti)
    x = zero(Ti)
    y = zero(Ti)

    # Source Nodes   => all - length=n
    # Midpoint Nodes => link_nodes - length=t
    # Destination nodes => All - length=n

    i = t_idx
    @inbounds while i <= n^2
        x, y = compute_idx(i, n)
        s = y
        d = x

        # Get current distance from matrix
        a = d_c[d,s]

        @inbounds for z = 1:t
            k = link_nodes[z]               # Get index of intermediate point
            b = d_c[k,s] + d_c[d,k]         # Compute path via intermediate point k
            a = (a <= b)*a + (a > b)*b      # Set a to min(a,b)
        end

        # Write minimum to matrix
        d_c[d,s] = a
        #loc_obj += (a != 0)*(convert(Tf, inv(a)) * M[d])
        loc_obj += (s != d)*(convert(Tf, inv(a)) * M[d])
        
        i += total_threads
    end

    # Sum loc_obj across warp
    n = div(warpsize(),2)
    while n > 0
        loc_obj += shfl_down_sync(FULL_MASK, loc_obj, n, warpsize())
        n = div(n,2)
    end

    # Atomic add the local result into result pointer
    if laneid() == 1      
        CUDA.atomic_add!(pointer(result), loc_obj)
    end

    return nothing   
end


function compute_obj_gpu(gpu_data::GPUDatasets{Tf}, d_t::CuArray{Tf, 2, CUDA.DeviceMemory}, link_nodes::CuArray{Ti, 1, CUDA.DeviceMemory}) where {Ti<:Integer, Tf<:AbstractFloat}

    # TODO make this configurable in some way
    threads = 640
    blocks = 60

    # Shortcuts for gpu_data values
    d_w = gpu_data.d_w
    d_c = gpu_data.d_c
    M = gpu_data.M
    offset = gpu_data.offset

    # Compute sizes
    n = convert(Ti, size(d_w)[1])
    t = convert(Ti, size(d_t)[1])

    # Rest to walk graph
    @cuda threads=threads blocks=blocks reset_dist!(n, d_w, d_c)

    # Write in transit graph
    @cuda threads=threads blocks=blocks write_transit!(t, convert(Tf, settings[:waiting_time]), d_c, d_t, link_nodes, offset)
    
    # Update transit nodes
    @cuda threads=threads blocks=blocks update_link_nodes!(n, t, d_c, link_nodes)

    result = cu([zero(Tf)])
    @cuda threads=threads blocks=blocks update_and_compute!(n, t, d_c, link_nodes, M, result)

    return Array{Tf}(result)[1]
end