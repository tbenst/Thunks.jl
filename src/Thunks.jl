module Thunks

include("core.jl")
include("macros.jl")

export Thunk, reify, thunk, @lazy
end
