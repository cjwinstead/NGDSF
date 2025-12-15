using Plots

struct TestPoint
    SNR::Float64
    dec::Decoder
    ec::ErrorCounter
    uc::ErrorCounter
end

@with_kw mutable struct Experiment
    name=String("Unnamed Experiment")
    description=String("none")
    notes=String("")
    code::BlockCode
    m::Modulation
    data=Vector{TestPoint}()
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
