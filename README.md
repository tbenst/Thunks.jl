# Thunks.jl

[![Documentation](https://img.shields.io/badge/docs-master-blue.svg)](https://tbenst.github.io/Thunks.jl/dev)
[![Build Status](https://github.com/tbenst/Thunk.jl/workflows/CI/badge.svg)](https://github.com/tbenst/Thunks.jl/actions)
[![Coverage](https://codecov.io/gh/tbenst/Thunk.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tbenst/Thunks.jl)

Thunks.jl provides a simple implementation of a
[Thunk](https://en.wikipedia.org/wiki/Thunk) for lazy computation.

A thunk represents a computation that is not run until we `reify` it,
meaning make "real". Once reified, the thunk caches the value of the
computation. The [core implementation](src/Thunks.jl) is only 25 LOC, so consider taking
a peak.

## Installation
```
julia> ] add https://github.com/tbenst/Thunks.jl
```
## Usage
Note that the below example will execute nearly instantly due to laziness,
whereas the eager equivalent would take a minute.
```julia
w = thunk(sleep)(60)
x = thunk(identity)(2)
y = @thunk identity(3)
@thunk yy = identity(3)
z = thunk(+)(x, y)
@assert z.evaluated == false
@assert reify(z) == 5
@assert z.evaluated == true
@assert w.evaluated == false
```

A macro is also provided for convenience:
```julia
abc = @thunk begin
    w = sleep(60)
    a = 2
    b = 3
    c = 1
    sum([a,b,c])
end
@assert reify(abc) == 6
```

## Limitations
Currently, naked indexing is not supported:
```julia
i = 10
x = @thunk collect(1:i)[7:end]
@assert isnothing(x)
x = thunk(collect)(1:i)[7:end]
ERROR: MethodError: no method matching lastindex(::Thunk)
```

This can be worked around by wrapping in a function
```julia
x = @thunk (()->collect(1:i)[7:end])()
```

## Acknowledgements
Thunks.jl is inspired by the Thunk implementation of the fantastic
[Dagger.jl](https://github.com/JuliaParallel/Dagger.jl)
and is intended as a lightweight, more performant alternative
without the scheduling capabilities.
