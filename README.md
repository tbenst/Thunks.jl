# Thunks.jl

[![Build Status](https://github.com/tbenst/Thunk.jl/workflows/CI/badge.svg)](https://github.com/tbenst/Thunk.jl/actions)
[![Coverage](https://codecov.io/gh/tbenst/Thunk.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/tbenst/Thunk.jl)
[![Documentation][(docs-master-img](https://img.shields.io/badge/docs-master-blue.svg)](https://juliaparallel.github.io/Dagger.jl/dev)

Thunks.jl provides a simple implementation of a
[Thunk](https://en.wikipedia.org/wiki/Thunk) for lazy computation.

A thunk represents a computation that is not run until we `reify` it,
meaning make "real". Once reified, the Thunk caches the value of the
computation.

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
y = thunk(identity)(3)
z = thunk(+)(x, y)
@assert z.evaluated = false
@assert reify(z) == 5
@assert z.evaluated = true
@assert w.evaluated = false
```

A macro is also provided:
```julia
abc = @thunk begin
    a = 1
    b = 2
    c = 4
    sum([a,b,c])
end
reify(abc)