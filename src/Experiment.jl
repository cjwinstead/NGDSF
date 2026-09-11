using Plots,Dates,Git,Suppressor
import Base.print

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
    modulation::Modulation
    data=Vector{TestPoint}()
end


function report(chan::ComplexAWGN)
    println(typeof(chan)," Q=",chan.Q," Eb/N₀=",chan.Eb_N₀," R=",chan.R)
end

function report(dec::Decoder)
    print(typeof(dec),":",typeof(dec.modulation),"  params:")
    print("params:")
    for p in fieldnames(typeof(dec))
        val = getfield(dec,p)
        if typeof(val) <: Number
            print(" ",string(p),"=",string(val))
        end
    end
end


function report(ect::ErrorCounter)
    for f in [:total_words,:word_errors,:bit_errors,:BER,:WER]
        println(string(f)," ",getfield(ect,f))
    end
end


function report(tp::TestPoint)
    println('-'^24," Test Point ",'-'^24)
    report(tp.chan)
    report(tp.dec)
    println("....... Coded Error Counter ......")
    report(tp.ec)
    println("...... Uncoded Error Counter ......")
    report(tp.uc)
    println('-'^60)
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

    return readchomp(`$git rev-parse --short HEAD`)
end


function runSweep!(e::Experiment,sym::Symbol,vals::Vector,setup)
    for v in vals
        chan,dec=setup(sym,v)
        ec,uc = simulate(e.code,e.modulation,chan,dec;maxwords=10,errwords=10)
        println(ec)
        println(uc)
        tp = TestPoint(chan,dec,ec,uc)
        report(tp)

        push!(e.data,tp)
        save(experiment)
    end    
end


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
