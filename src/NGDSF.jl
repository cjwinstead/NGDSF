using Parameters,BlockCodes
import BlockCodes.decode

@with_kw struct NGDSF <: Decoder
    code::BlockCode
    modulation::Modulation
    chan::ComplexChannel
    T::Integer
    w::Float64
    η::Float64
    κ::Integer
    λ::Integer
end

@with_kw mutable struct NGDSF_state
    parameters::NGDSF
    y::Vector
    d::Vector
    S::Vector
    Sb::Vector
    Hb::Matrix
    num_satisfied::Integer
    num_unsatisfied::Integer
    l::Integer
end


function NGDSF_state(parameters::NGDSF,y,d)
    @unpack_NGDSF parameters
    
    S  = syndrome(d,code)
    Sb = S .== 0

    num_satisfied = sum(Sb)
    num_unsatisfied = code.M - num_satisfied
    Hb = code.H .≠ 0
    l  = 0
    
    return NGDSF_state(parameters,y,d,S,Sb,Hb,num_satisfied,num_unsatisfied,l)
end


function iteration!(a::NGDSF_state)
    @unpack_NGDSF_state a
    @unpack_NGDSF parameters

    l += 1
    S  = syndrome(d,code)
    Sb = S .== 0

    num_satisfied = sum(Sb)
    num_unsatisfied = code.M - num_satisfied

    # Calculate reliability metrics
    WSH = w .* transpose(Hb)*Sb
    E   = -abs.(y .- modulate(d,modulation)).^2 ./ chan.N₀ .+ WSH .+ η.*randn(code.N); 
    
    # Find k least-reliable positions
    # randomly choose one of them to flip
    weakest_positions = min_k(E,κ)
    flip_position     = rand(weakest_positions)

    # Find the nearest symbol neighbors
    # and randomly pick one
    nearest_neighbors = min_k( abs.(y[flip_position] .- modulation.constellation), λ)
    new_symbol       = rand(nearest_neighbors)

    # Test the new symbol to see if it lowers the number of
    # of unsatisfied checks
    d′ = copy(d)
    d′[flip_position] = modulation.field[new_symbol]

    S′  = syndrome(d′,code)
    Sb′ = S′ .== 0

    num_satisfied′ = sum(Sb′)
    if num_satisfied′ >= num_satisfied
        d,S,Sb = d′,S′,Sb′
        num_satisfied = num_satisfied′
    end
    
    @pack_NGDSF_state! a
end

function min_k(v::Vector,k::Integer)
    if k < length(v)
        return sortperm(v)[1:k]
    else
        return sortperm(v)
    end
end


function decode(state::NGDSF_state)
    while (state.l < state.parameters.T) && (state.num_unsatisfied > 0)
        iteration!(state)
    end
    return state.d
end

function decode(y::Vector,r::Vector,dec::NGDSF)
    state = NGDSF_state(dec,y,r)
    return decode(state)
end


