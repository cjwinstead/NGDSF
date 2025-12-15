using REPL.TerminalMenus, Plots, Serialization

include("NGDSF.jl")
include("Experiment.jl")


files = readdir("results/")

results = Vector{Experiment}()

for f in files
    e=deserialize(joinpath("results/",f))
    push!(results,e)
end

names = map(x->x.name,results)

menu    = MultiSelectMenu(names)
choices = request("Select results to plot",menu)

SNR    = Vector{Vector{Float64}}()
BER    = Vector{Vector{Float64}}()
labels = String[]

for i in choices
    d = results[i].data
    b = map(x->x.ec.BER,d)
    s = map(x->x.SNR,d)
    idx = findall(x->x>0,b)
    push!(SNR,s[idx])
    push!(BER,b[idx])

    global labels=cat(labels,results[i].name;dims=1+(length(labels)>0))
end

Plots.plot(SNR,BER;
           label=labels,
           yscale=:log10,
           ylims=(1e-7,0.01)
     )

