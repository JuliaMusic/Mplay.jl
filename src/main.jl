include("Mplay.jl")

using .Mplay

if length(ARGS) > 0
    device = length(ARGS) > 1 ? ARGS[2] : ""
    mplay(ARGS[1], device)
end
