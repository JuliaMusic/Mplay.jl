include("Mplay.jl")

using .Mplay

if length(ARGS) > 0
     mplay(ARGS[1])
end
