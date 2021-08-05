using Thunk
using Test

@testset "reify" begin
    x = thunk(identity)(2)
    y = thunk(identity)(3)
    z = thunk(+)(x, y)
    @assert reify(z) == 5
end
