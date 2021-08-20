module Thunks

include("core.jl")
include("macros.jl")

export Thunk, Unevaluated, Reversible, Think, Checkpointable, reify, thunk, @lazy,
    @noeval, @reversible, undo
end
