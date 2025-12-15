using Parameters,Serialization,Dates

include("src/NGDSF.jl")
include("src/Experiment.jl")


# Modulation
m    = QAM(16)

# Hamming code and syndrome decoder
code = hamming_code(GF(16),3)
dec  = SyndromeDecoder(code)

# Initialize log for Hamming code

experiment =    Experiment(name="Hamming (7,4)",
                           code=code,
                           m=m)
experiment.description="(7,4) Hamming code over 𝔽₁₆"
experiment.notes="""
A short non-binary Hamming code simulated with QAM 16 modulation
on AWGN channel. Decoder is a syndrome LUT.
"""


#========================================================
 MAIN SIMULATION LOOP
========================================================#
println("Simulating $(experiment.name)")

    
for SNR in [9.0,10.0,11.0,12.0,13.0,14.0,15.0]

    # Simulate 
    chan  = ComplexAWGN(SNR,16,code.R,m.Es)
    ec,uc = simulate(code,m,chan,dec;maxwords=1000)

    # Save results to log
    push!(experiment.data,TestPoint(SNR,dec,ec,uc))

    serialize("results/$(experiment.name)_$(typeof(m))_$(Dates.today()).ser",experiment)
end




