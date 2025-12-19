using REPL.TerminalMenus, Plots, Serialization

include("NGDSF.jl")
include("Experiment.jl")


files = readdir("results/")

results = Vector{Experiment}()

for f in files
    e=deserialize(joinpath("results/",f))
    push!(results,e)
end

parameters   = [:SNR,:T,:w]
names        = map(x->x.name,results)
measurements = [:BER,:WER]

menu    = MultiSelectMenu(names)
choices = request("Select results to plot",menu)

xmenu = RadioMenu(string.(parameters))
xchoice = parameters[request("Select X axis",xmenu)]

ymenu = RadioMenu(string.(measurements))
ychoice = measurements[request("Select Y axis",ymenu)]

xdata  = Vector{Vector{Float64}}()
ydata  = Vector{Vector{Float64}}()
labels = String[]



for i in choices
    let d=results[i].data
        b = map(y->getproperty(y.ec,ychoice),d)
        s = map(x->getproperty(x,xchoice),d)

        idx = findall(x->x>0,b)
        push!(xdata,s[idx])
        push!(ydata,b[idx])

        global labels=cat(labels,results[i].name;dims=1+(length(labels)>0))
    end
end

Plots.plot(xdata,ydata;
           label=labels,
           yscale=:log10,
           ylims=(1e-7,0.01),
           xlabel=string(xchoice),
           ylabel=string(ychoice),
           markershape=:auto
     )

