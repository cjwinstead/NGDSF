using Parameters,Serialization,Dates

include("src/NGDSF.jl")
include("src/Experiment.jl")


# Modulation
m    = QAM(16)

# NBLDPC Code Definition
code = BlockCode(GF(16),"codes/204.102.3.6.16.csv")

T    = 480
SNR  = 6.0

# Initialize log for NBLDPC code
experiment = Experiment(code=code,m=m)
experiment.name="NGDSF_T$(T)"
experiment.description="N=204 NBLDPC over 𝔽₁₆ decoded with NGDSF"
experiment.notes="""
Noisy Gradient Descent Symbol Flipping experiment on QAM16 AWGN channel.
Parameters chosen to replicate Zinnia's Matlab implementation. 
"""

result_filename = joinpath("results","$(experiment.name)_$(experiment.date)_$(experiment.commit).ser")
if isfile(result_filename)
    experiment=deserialize(result_filename)
end

# Macro for NGDSF decoder declaration. Using a macro because
# there are parameters that depend on channel SNR, but most
# do not. Could also do this with a function I guess.

macro dec(chan)
    quote
        NGDSF(
            code=code,
            modulation=m,    
            chan=$(esc(chan)),
            T=T,
            w=25,
            η=0.3,
            κ=6,
            λ=4
        )
    end        
end



function setup(sym,val)
    if sym == :SNR
        chan  = ComplexAWGN(val,16,code.R,m.Es)
        dec   = @dec(chan)
    else
        chan  = ComplexAWGN(SNR,16,code.R,m.Es)
        dec   = @dec(chan)
        eval(:($(dec).$(sym)=$(val)))
    end
    
    return chan,dec
end


function save(e::Experiment)
    serialize(result_filename,e)
end


#========================================================
 MAIN SIMULATION LOOP
========================================================#
#=
println("Simulating $(experiment.name)")
    
for SNR in [9.0,9.5,10.0,10.5,11.0]

    # Simulate 
    chan  = ComplexAWGN(SNR,16,code.R,m.Es)
    dec   = @dec(chan)
    ec,uc = simulate(code,m,chan,dec;maxwords=100000)

    # Save results to log
    println("At SNR=$(SNR)  BER=$(ec.BER)")
    push!(experiment.data,TestPoint(SNR,dec,ec,uc))

    serialize(joinpath("results","$(experiment.name)_$(typeof(m))_$(m.field.Q)_$(typeof(chan))_$(Dates.today()).ser"),experiment)
end
=#




