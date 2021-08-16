"Abstract type for Thunks."
abstract type Think end

"""
    Thunk(function, args, kwargs)

Type that represents a thunk. Only `evaluated` is a public field.
Use `reify` to evaluate. Evaluates to Weak head normal form, meaning that
non-free symbols must be assigned / defined. Contrast with Unevaluated.
"""
mutable struct Thunk <: Think
    f::Any # usually a Function, but could be any callable
    # args will be passed to f. Needs to support ... (splat), eg Array or Tuple
    args::Any
    kwargs::Dict # kwargs will be passed to f, cleared after evaluation
    evaluated::Bool # false until computed, then true
    result::Any # cache result once computed
    Thunk(f, args) = new(f, args, Dict(), false, nothing)
    Thunk(f, args, kwargs) = new(f, args, kwargs, false, nothing)
end

"""
Keep expression, including args/kwargs, as unevaluated.
"""
mutable struct Unevaluated <: Think
    f::Any # usually a Function, but could be any callable
    # args will be passed to f. Needs to support ... (splat), eg Array or Tuple
    args::Any # a primitive thunk of the form: () -> tuple
    kwargs::Any # a primitive thunk of the form: () -> dict
    evaluated::Bool # false until computed, then true
    result::Any # cache result once computed
    Unevaluated(f, args) = new(f, args, ()->Dict(), false, nothing)
    Unevaluated(f, args, kwargs) = new(f, args, kwargs, false, nothing)
end

function Base.getindex(self::Think, index)
    thunk(getindex)(self, index)
end

Base.iterate(t::Think, state=1) = (t[state], state+1)

function thunk(f)
    (args...; kwargs...) -> Thunk(f, args, kwargs)
end

"""
    reify(thunk::Think)
    reify(value::Any)

Reify a thunk into a value.

In other words, compute the value of the expression.

We walk through the thunk's arguments and keywords, recursively evaluating each one,
and then evaluating the thunk's function with the evaluated arguments.
"""
function reify(thunk::Think)
    if thunk.evaluated
        return thunk.result
    else
        args = [reify(x) for x in thunk.args]
        kwargs = Dict(k => reify(v) for (k,v) in thunk.kwargs)
        return eval_thunk(thunk, thunk.f, args, kwargs)
    end
end

function reify(thunk::Unevaluated)
    if thunk.evaluated
        return thunk.result
    else
        args = [reify(x) for x in thunk.args()]
        kwargs = Dict(k => reify(v) for (k,v) in thunk.kwargs())
        return eval_thunk(thunk, thunk.f, args, kwargs)
    end
end

function eval_thunk(thunk, f, args, kwargs)
        thunk.result = thunk.f(args...; kwargs...)
        thunk.evaluated = true
        # clear to allow garbage collection
        thunk.args = []
        thunk.kwargs = Dict()
        return thunk.result
end

function reify(value)
    value
end