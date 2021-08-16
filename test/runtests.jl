using Thunks
using Test

"Fail test on error without stopping testset. Not totally working..?"
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

@testset "find symbols in ast" begin
    ex = :([x[1:2] for x in repeat([repeat([a], 3)],3)])
    symbols = Thunks.find_symbols_in_ast(ex)
    @test all([x in symbols for x in [:a, :repeat, :x]])
    ex2 = :(begin
        z = a + 3
        y = collect(1:b)
        abc = x -> rand(3,5)[2:3, 2:3]
    end)
    symbols2 = Thunks.find_symbols_in_ast(ex2)
    @test all([x in symbols2 for x in [:z, :a, :y, :b, :collect, :abc, :rand, :x]])
end

@testset "find assigned symbols in ast" begin
    ex0 = :(collect(1:b; fakekeyword=1, fake=2))
    symbols0 = Thunks.find_assigned_symbols_in_ast(ex0)
    @test all([~in(x, symbols0) for x in [:fakekeyword, :fake]])

    ex = :([x[1:2] for x in repeat([repeat([a], 3)],3)])
    symbols = Thunks.find_assigned_symbols_in_ast(ex)
    @test all([x in symbols for x in [:a, :repeat]])
    @test (~)(:x in symbols)
    
    ex2 = :(begin
        z = a + 3
        y = collect(1:b, fakekeyword=1)
        abc = x -> rand(3,5)[2:3, 2:3]
    end)
    symbols2 = Thunks.find_assigned_symbols_in_ast(ex2)
    @test all([x in symbols2 for x in [:z, :a, :y, :b, :collect, :abc, :rand]])
    @test all([~in(x, symbols2) for x in [:x, :fakekeyword]])
end


# quick test
# using Thunks; begin x=y=z=1; a = @lazy sum([x,y,z]); reify(a); end

@testset "@lazy" begin
    a = b = c = 2
    t = @lazy sum([a,b,c])
    @test typeof(t) == Thunk
    @test reify(t) == 6
    @lazy begin
        x = 1
        b = 2
        z = 4
        abc = sum([x,b,z])
    end
    @test typeof(abc) == Thunk
    @test reify(abc) == 7
end

function add1(x)
    x + 1
end

@testset "dot broadcast" begin
    a = ones(5)

    @lazy b = a .+ a
    @test all(reify(b) .== (a .*2))
    
    @lazy c = add1.(a)
    @test all(reify(c) .== (a .+ 1))
end

test() = (1,2,3)

@testset "indexing" begin
    @lazy x = test()[1]
    @test reify(x) == 1
    @lazy y = test()
    y1 = y[1]
    @test reify(y1) == 1
    i = @lazy identity(10)
    x = @lazy collect(1:i)[7:end]
    @test all(reify(x) .== [7,8,9,10])
end

@testset "if" begin
        @lazy x = true ? 1 : 0
        @test reify(x) == 1
        y = @lazy if true
            1
        else
            0
        end
        @test reify(y) == 1
end

@testset "return arity" begin
    @lazy x,y,z = test()
    @test map(reify,(x,y,z)) == (1,2,3)
    @lazy (a,b,c) = test()
    @test map(reify,(x,y,z)) == (1,2,3)
end

function maybe_add1(x; add1=false)
    y = add1 ? x + 1 : x
    y*2
end


@testset "kwargs" begin
    @lazy y = maybe_add1(2; add1=false)
    @test reify(y)==4
    @lazy yy = maybe_add1(2; add1=true)
    @test reify(yy)==6
end

@testset "comprehension Expr" begin
    a = @lazy identity(6)
    z = @lazy [x[1:2] for x in repeat([repeat([a], 3)],3)]
    @test all(sum(reify(z)) .== [18, 18])
end

@testset "Unevaluated" begin
    # will not error
    not_used = Unevaluated(+, ()->(not_defined,1))
    a = Unevaluated(identity, ()->1)
    b = Unevaluated(identity, ()->2)
    c = Unevaluated(+, ()->(a,b))
    @test reify(c) == 3
end

@testset "@noeval" begin
    # will not error
    @noeval begin
        not_used = not_defined + 1
        a = identity(1)
        b = identity(2)
        c = a + b
    end
    # behavior may be unexpected if referential transparency does not hold.
    b = -2
    @test reify(c) == -1
end

end