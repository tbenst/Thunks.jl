"""
    Thunk(function, args, kwargs)

Type that represents a thunk. Useful fields inclue:
```
    evaluated::Bool
    result::Any
```
"""
mutable struct Thunk
    f::Any # usually a Function, but could be any callable
    args::Tuple # args will be passed to f
    kwargs::Dict # kwargs will be passed to f
    evaluated::Bool # false until computed, then true
    result::Any # cache result once computed
    Thunk(f, args, kwargs) = new(f, args, kwargs, false, nothing)
end

function thunk(f)
    (args...; kwargs...) -> Thunk(f, args, kwargs)
end

"""
    reify(thunk::Thunk)
    reify(value::Any)

Reify a thunk into a value.

In other words, compute the value of the expression.

We walk through the thunk's arguments and keywords, recursively evaluating each one,
and then evaluating the thunk's function with the evaluated arguments.
"""
function reify(thunk::Thunk)
    if thunk.evaluated
        return thunk.result
    else
        args = [reify(x) for x in thunk.args]
        kwargs = Dict(k => reify(v) for (k,v) in thunk.kwargs)
        thunk.result = thunk.f(args...; kwargs...)
        thunk.evaluated = true
        return thunk.result
    end
end

function reify(value)
    value
end