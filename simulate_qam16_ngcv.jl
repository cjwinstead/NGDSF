using Parameters,Serialization,Dates

include("src/NGCV.jl")
include("src/Experiment.jl")


# Modulation
modulation  = QAM(16)

# NBLDPC Code Definition
code     = BlockCode(GF(16),"codes/204.102.3.6.16.csv")
codename = "204.102.3.6.16"

#modulation  = ASK(2)
#code = hamming_code(GF(2),3)
#codename = "Hamming"

params = [:SNR,:T,:w,:η,:θ]

T    = 3
SNR  = 6.0
w    = 37
η    = 12.0
θ    = 3

# Initialize log for NBLDPC code
experiment = Experiment(;code,modulation)
experiment.name="NGCV"
experiment.description="N=204 NBLDPC over 𝔽₁₆ decoded with NGCV"
experiment.notes="""
Noisy Gradient Check Voting experiment on QAM16 AWGN channel.
Parameters chosen to replicate Zinnia's Matlab implementation. 
"""

result_path = joinpath("results",experiment.name,codename,experiment.commit)
mkpath(result_path)
result_filename = joinpath(result_path,"$(experiment.date).ser")
if isfile(result_filename)
    experiment=deserialize(result_filename)
end




function setup(sym,val)

    eval(:($(sym)=$(val)))    
    chan = ComplexAWGN(SNR,16,code.R,modulation.Es)
    dec = NGCV(code,
               modulation,
               chan,
               T,
               w,
               η,
               θ
               )
    
    return chan,dec
end


function save(e::Experiment)
    serialize(result_filename,e)
end


println("""
The environment is setup for an experiment named $(experiment.name)

Current settings:
$(for x in params
println(string(x),"=",eval(x))
end)

Change any parameter as desired before running a simulation.
To sweep a parameter, use runSweep!(experiment,symbol,values)

example: the command below will simulate a range of SNRs

runSweep!(experiment,:SNR,collect(8.0:1.0:13.0))
""")

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




