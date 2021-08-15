# Thunks.jl

[![Documentation](https://img.shields.io/badge/docs-master-blue.svg)](https://tbenst.github.io/Thunks.jl/dev)
[![Build Status](https://github.com/tbenst/Thunk.jl/workflows/CI/badge.svg)](https://github.com/tbenst/Thunks.jl/actions)
[![Coverage](https://codecov.io/gh/tbenst/Thunk.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tbenst/Thunks.jl)

Thunks.jl provides a simple implementation of a
[Thunk](https://en.wikipedia.org/wiki/Thunk) for lazy computation, and a 
sophisticated macro `@lazy` that rewrites arbitrary Julia expressions for 
a lazy evaluation strategy.

A thunk represents a computation that is not run until we `reify` it,
meaning make "real". Once reified, the thunk caches the value of the
computation. The [core implementation](src/core.jl) is only 30 LOC, so
consider taking a peak. Most of the complexity lies in the `@lazy` macro,
which aims to support lazy evaluation of arbitrary Julia expressions, including
dot broadcasting, indexing, keyword arguments, if blocks, comprehensions, and
more.

The implementation approximates laziness in pure functional languages
like Haskell: a memoizing [call-by-need](https://en.wikipedia.org/wiki/Lazy_evaluation).
This means that a computation captured in a thunk is run 0 or 1 times,
with subsequent calls re-using ("sharing") the result of the previous
evaluation.

## Installation
```
julia> ] add Thunks
```
## Usage
Note that the below example will execute nearly instantly due to laziness,
whereas the eager equivalent would take a minute.
```julia
w = thunk(sleep)(60)
x = thunk(identity)(2)
# equivalent to line above
y = @lazy identity(2)
# also equivalent
@lazy yy = identity(2)
z = thunk(+)(x, y)
@assert z.evaluated == false
@assert reify(z) == 4
@assert z.evaluated == true
@assert w.evaluated == false
```

The `@lazy` macro also supports code blocks:
```julia
@lazy begin
    w = sleep(60)
    a = 2
    b = 3
    c = 1
    abc = sum([a,b,c])
end
@assert typeof(w) == Thunk
@assert typeof(a) == Int
@assert typeof(abc) == Thunk
@assert reify(abc) == 6
```

`@lazy` aims to support arbitrary Julia expressions:
```julia
test() = (1,2,3)
@lazy begin
    a = true ? (()-> ones(5))() : zeros(5)
    b = a .+ a
    c = collect(1:b[3]*5)[7:end]
    d = identity(6)
    e = [x[1:2] for x in repeat([repeat([d], 3)],3)]
end
@assert reify(c) == [7,8,9,10]
@assert e.evaluated == false
@assert all(sum(reify(e)) .== [18, 18])
@assert e.evaluated == true
```

More usage examples can be seen in the [tests](test/runtests.jl).

## Limitations
Currently, using `@lazy` on nested blocks is not supported.

## Acknowledgements
Thunks.jl is inspired by the Thunk implementation of the fantastic
[Dagger.jl](https://github.com/JuliaParallel/Dagger.jl)
and is intended as a lightweight, more performant alternative
without the scheduling capabilities.
