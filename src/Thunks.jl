module Thunks

include("core.jl")
include("macros.jl")

export Thunk, Unevaluated, Think, reify, thunk, @lazy, @noeval
end
