#=

Noisy Gradient Check Voting decoder (NGCV)

=#

using Parameters,BlockCodes
import BlockCodes.decode


# NGCV is a struct with decoder parameters
@with_kw mutable struct NGCV <: Decoder
    code::BlockCode
    modulation::Modulation
    chan::ComplexChannel
    T::Integer
    w::Float64
    η::Float64
    θ::Integer
    postproc::Bool
end


# NGCV_state holds variables specific to a
# received frame and iteration.
@with_kw mutable struct NGCV_state
    parameters::NGCV
    y::Vector         # channel samples
    d::Vector         # decoded decisions
    d′::Vector        # proposed decisions
    s::Vector         # syndrome (non-binary)
    u::Vector         # satisfation (binary)
    e::Vector         # reliability metrics 
    B::Matrix         # binary connectivity matrix
    λ::Integer        # number of unsatisfied checks
    λ′::Integer       # number of unsatisfied checks after iteration
    ℓ::Integer        # iteration number
    stop::Bool        # stopping condition met
end

include("utilities.jl")


# Initialization Constructor
function NGCV_state(parameters::NGCV,y,r)
    @unpack_NGCV parameters

    d  = copy(r)
    d′ = copy(d)
    
    s = syndrome(d,code)
    u = s .≠ 0

    λ  = sum(u)
    λ′ = 0
    B  = code.H .≠ 0
    ℓ  = 0

    e = Vector{Float64}()
    
    stop = false

    #println("%% new decoding instance %%")
    #println("y=$y")
    #println("d=$d")
    return @pack_NGCV_state 
end


# Constructor alias:
initialize(parameters::NGCV,y,r) = NGCV_state(parameters,y,r)
    

    

function □!(a::NGCV_state)
    @unpack_NGCV_state a
    @unpack_NGCV parameters
    
    s′  = syndrome(d′,code)
    u′  = s′ .≠ 0
    λ′ = sum(u′)
    
    if λ′ < λ
        println("    □  λ $λ ⟶ $λ′")
        d    = copy(d′)
        λ    = λ′
        s    = copy(s′)
        u    = copy(u′)
    end
    
    d′   = copy(d)

    #println("   □  s=$s")
    #println("   □  u=$u")
    #println("   □  λ=$λ")
    #println("   □  λ′=$λ′")

    @pack_NGCV_state! a
end

function ℛ!(a::NGCV_state)
    @unpack_NGCV_state a
    @unpack_NGCV parameters
    
    β = w.*transpose(B)*u
    e = -abs.(y .- modulate(d,modulation)).^2 ./ chan.N₀ .+ β .+ η.*randn(code.N)
    
    #println("   ℛ  β=$β")
    #println("   ℛ  e=$e")
    
    @pack_NGCV_state! a
end


function Δ!(a::NGCV_state)
    @unpack_NGCV_state a
    @unpack_NGCV parameters
    
    # Find θ least-reliable positions
    weakest_positions = min_k(e,θ)
    #println("    Δ weakest_positions=$weakest_positions")
    #println("    Δ y[]=",[y[i] for i in weakest_positions])
    #println("    Δ e[]=",[e[i] for i in weakest_positions])
    for v in weakest_positions
        π       = partial_syndromes(code,v,d[v],s)
        #println("    Δ π=$π")
        syms    = unique(π)
        votes   = [ count(a->a==b,π) for b in syms ]
        winners = findmax(votes)[2]

        #println("    Δ winners=$winners")
        try
            if length(winners)==1
                d′[v] = syms[winners[1]]
                #println("    Δ  Flipping sym $v from $(d[v]) to $(d′[v])")
            else
                candidates = [ syms[j] for j in winners ]
                i     = nearest_points(y[v],modulate(candidates,modulation)) # Euclidean distance
                d′[v] = syms[winners[i]]
                #println("    Δ Flipping sym $v from $(d[v]) to $(d′[v])")
            end
        catch err
            println("v=",v)
            println("π=",π)
            println("syms=",syms)
            println("winners=",winners)
            println("votes=",votes)
        end
    end
    @pack_NGCV_state! a    
end

function 𝒮!(a::NGCV_state)
    a.stop = a.λ == 0 || a.ℓ ≥ a.parameters.T
    #println("   𝒮  $(a.stop)")
end

function iteration!(a::NGCV_state)
    # Algorithm: ⊞𝒮ℛΔ
    # 1. □  Parity-check phase
    # 2. 𝒮 Stopping codition (checks satisfied)
    # 3. ℛ  Evaluate all reliability metrics
    # 4. Δ  Update decisions
    
    a.ℓ += 1  # increment iteration count

    #println("Iteration ℓ=$(a.ℓ)")
    □!(a)  # parity check operations
    𝒮!(a) # evaluate stopping condition
    
    if !a.stop 
        ℛ!(a)  # reliability metric
        Δ!(a)  # update decisions        
    end
        
    return a
end


function 𝒫!(a::NGCV_state)
    @unpack_NGCV_state a
    @unpack_NGCV parameters

    checks = [ check_node_neighbors[vn] for vn in u]
    candidates = unique([ sym_node_neighbors[ck] for ck in checks ])
    
    for vn in candidates
        d′ = copy(d)
        for sym in code.field.elements
            d′[vn] = sym
            s′  = syndrome(d′,code)
            u′  = s′ .≠ 0
            λ′ = sum(u′)
            if (λ′ < λ)
                d[vn] = sym
                λ     = λ′
            end            
        end
    end

    @pack_NGCV_state! a
end


function postprocess!(a::NGCV_state)
    □!(a)
    𝒫!(a)
    𝒮!(a)
end



