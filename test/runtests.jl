using Thunks
using Test

"Fail test on error without stopping testset."
macro safetest(ex)
    return quote
        @test try
            @eval $(esc(ex))
        catch err
            throw(err)
            false
       end
    end
end
@testset "all" begin

@testset "reify" begin
    x = thunk(identity)(2)
    y = thunk(identity)(3)
    z = thunk(+)(x, y)
    @test typeof(x) == typeof(y) == typeof(z) == Thunk
    @test z.evaluated == x.evaluated == y.evaluated == false
    @test z.result == x.result == y.result == nothing
    @test reify(z) == 5
    @test z.evaluated == x.evaluated == y.evaluated == true
    @test z.result == 5
    @test x.result == 2
end

@testset "safe_eval_isthunk" begin
    a = @thunk identity(6)
    @test typeof(eval(:( (()->a)(a) ))) == Thunk
    # @test Thunks.safe_eval_isthunk(:(a))
end

@testset "find symbols in ast" begin
    a = @thunk identity(6)
    ex = :([x[1:2] for x in repeat([repeat([a], 3)],3)])
    symbols = Thunks.find_symbols_in_ast(ex)
    @test :a in symbols
    @test :repeat in symbols
    @test :x in symbols
    @thunk b = 3 * a
    ex2 = :(begin
        z = a + 3
        y = collect(1:b)
        abc = x -> rand(3,5)[2:3, 2:3]
    end)
    symbols2 = Thunks.find_symbols_in_ast(ex2)
    @test all([x in symbols2 for x in [:z, :a, :y, :b, :collect, :abc, :rand, :x]])
end

@testset "find thunks in ast" begin
    a = @thunk identity(6)
    ex = :([x[1:2] for x in repeat([repeat([a], 3)],3)])
    symbols = Thunks.find_thunks_in_ast(ex)
    @test symbols == [:a]

    @thunk b = 3 * a
    ex2 = :(begin
        z = a + 3
        y = collect(1:b)
        abc = x -> rand(3,5)[2:3, 2:3]
    end)
    symbols2 = Thunks.find_thunks_in_ast(ex2)
    @test all([x in symbols2 for x in [:a, :b]])
end

@testset "@thunk" begin
    a = b = c = 2
    t = @thunk sum([a,b,c])
    @test typeof(t) == Thunk
    @test reify(t) == 6

    abc = @thunk begin
        a = 1
        b = 2
        c = 4
        sum([a,b,c])
    end
    @test typeof(abc) == Thunk
    @test reify(abc) == 7
end

function add1(x)
    x + 1
end

@testset "dot broadcast" begin
    a = ones(5)

    @safetest begin
        @thunk b = a .+ a
        all(reify(b) .== (a .*2))
    end
    
    add1(x) = x + 1
    @safetest begin
        @thunk c = add1.(a)
        all(reify(c) .== (a .+ 1))
    end
end

test() = (1,2,3)

@testset "indexing" begin
    @safetest begin
        @thunk x = test()[1]
        x == 1
    end
    @safetest begin
        i = @thunk identity(10)
        x = @thunk collect(1:i)[7:end]
        all(x .== [7,8,9,10])
    end
end

@testset "if" begin
    @safetest begin
        @thunk x = true ? 1 : 0
        x == 1
    end
    @safetest begin
        y = @thunk if true
            1
        else
            0
        end
        y == 1
    end
end

@testset "return arity" begin
    @safetest begin
        @thunk x,y,z = test()
        x,y,z == (1,2,3)
    end
    @safetest begin
        @thunk (a,b,c) = test()
        (a,b,c) == (1,2,3)
    end
end

function maybe_add1(x; add1=false)
    y = add1 ? x + 1 : x
    y*2
end


@testset "kwargs" begin
    @thunk y = maybe_add1(2; add1=false)
    @test reify(y)==4
    @thunk yy = maybe_add1(2; add1=true)
    @test reify(yy)==6
end

@testset "comprehension Expr" begin
    a = @thunk identity(6)
    z = @thunk [x[1:2] for x in repeat([repeat([a], 3)],3)]
    @assert all(sum(reify(z)) .== [18, 18])
end

end