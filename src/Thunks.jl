module Thunks

include("core.jl")
include("macros.jl")
#### remaining code in this module pertains to the @thunk macro


export Thunk, reify, thunk, @thunk
end
