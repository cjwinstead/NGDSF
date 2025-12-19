using Plots,Dates,Git,Suppressor

struct TestPoint
    chan::ChannelModel
    dec::Decoder
    ec::ErrorCounter
    uc::ErrorCounter
end

@with_kw mutable struct Experiment
    name=String("Unnamed Experiment")
    date=today()
    commit=githash()
    description=String("none")    
    notes=String("")
    code::BlockCode
    m::Modulation
    data=Vector{TestPoint}()
end


function githash()
    try
        @suppress(run(`$git diff --exit-code src/Experiment.jl`))
    catch e
        println("Warning: Experiment.jl has changed since last commit.")
        return ""
    end
    try
        @suppress(run(`$git diff --exit-code src/NGDSF.jl`))
    catch e
        println("Warning: NGDSF.jl has changed since last commit.")
        return ""
    end

    return run(`$git rev-parse --short HEAD`)
end


function runSweep!(e::Experiment,sym::Symbol,vals::Vector)
    for v in vals
        chan,dec=setup(sym,v)
        ec,uc = simulate(e.code,e.m,chan,dec;maxwords=100000)
        println("At $(string(sym))=$(v)  BER=$(ec.BER)")
        push!(e.data,TestPoint(chan,dec,ec,uc))
        save(experiment)
    end    
end


#=    
function runSimulation(e::Experiment)    
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


macro SNR(s)
    quote map(x->x.SNR,results[$(esc(s))].data) end
end

macro BER(s)
    quote map(x->x.ec.BER,results[$(esc(s))].data) end
end

macro UNCODED(s)
    quote map(x->x.uc.BER,results[$(esc(s))].data) end
end


function plot(m::Modulation)
    plotlimit = maximum(abs.(m.constellation))
    return plot(real.(m.constellation),imag.(m.constellation);
         seriestype=:scatter,
         ylims=(-plotlimit,plotlimit),
         xlims=(-plotlimit,plotlimit),
         title="$(typeof(m)) Constellation with $(m.field.Q) Symbols",
         xlabel="Real",ylabel="Imag"
         )
end

function plot(results)
    return plot([@SNR("NGDSF"),     @SNR("NGDSF"), @SNR("Hamming (7,4)")],
           [@UNCODED("NGDSF"), @BER("NGDSF"), @BER("Hamming (7,4)")];
           label=["uncoded" "NGDSF" "Hamming (7,4)"],
           yscale=:log10
           )
end
