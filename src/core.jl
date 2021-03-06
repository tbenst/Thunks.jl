"Abstract type for Thunks."
abstract type Think end
abstract type WrappedThink <: Think end
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

"""
A Thunk that can "undo" code evaluation. Does not clear f or args.

Useful for interactive coding. ie if you revise a function definition,
can undo & reify the thunk again.
"""
mutable struct Reversible <: Think
    f::Any # usually a Function, but could be any callable
    # args will be passed to f. Needs to support ... (splat), eg Array or Tuple
    args::Any
    kwargs::Dict # kwargs will be passed to f, cleared after evaluation
    evaluated::Bool # false until computed, then true
    result::Any # cache result once computed
    Reversible(f, args) = new(f, args, Dict(), false, nothing)
    Reversible(f, args, kwargs) = new(f, args, kwargs, false, nothing)
end


"No operation."
function noop(args...; kwargs...)
    nothing
end


"""
A Thunk that can be checkpointed.
"""
mutable struct Checkpointable <: WrappedThink
    wrapped_thunk::Think
    # function that takes value of wrapped_thunk, and stores the result, ie on disk
    checkpoint::Any
    # instead of evaluating wrapped_thunk, try restoring value from disk
    restore::Any # load the result. ideally, no dependencies
    Checkpointable(t,c,r) = new(t,c,r)
    Checkpointable(t,r) = new(t,noop,r)
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

function set_result(thunk::WrappedThink)
    set_result(thunk.wrapped_thunk)
end

function set_result(thunk::Think, result)
    thunk.result = result
    thunk.evaluated = true
    # clear to allow garbage collection
    thunk.args = []
    thunk.kwargs = Dict()
end

function set_result(thunk::Reversible, result)
    thunk.result = result
    thunk.evaluated = true
end


function reify(thunk::Think)
    if thunk.evaluated
        return thunk.result
    else
        args = [reify(x) for x in thunk.args]
        kwargs = Dict(k => reify(v) for (k,v) in thunk.kwargs)
        result = thunk.f(args...; kwargs...)
        set_result(thunk, result)
        return result
    end
end

function reify(thunk::Unevaluated)
    if thunk.evaluated
        return thunk.result
    else
        args = [reify(x) for x in thunk.args()]
        kwargs = Dict(k => reify(v) for (k,v) in thunk.kwargs())
        result = thunk.f(args...; kwargs...)
        set_result(thunk, result)
        return result
    end
end

function reify(thunk::Reversible)
    if thunk.evaluated
        return thunk.result
    else
        args = [reify(x) for x in thunk.args]
        kwargs = Dict(k => reify(v) for (k,v) in thunk.kwargs)
        result = thunk.f(args...; kwargs...)
        set_result(thunk, result)
        return result
    end
end

function reify(thunk::Checkpointable)
    if thunk.wrapped_thunk.evaluated
        return thunk.wrapped_thunk.result
    end
    result = nothing
    try
        result = reify(thunk.restore)
    catch
        for (exc, bt) in Base.catch_stack()
            showerror(stdout, exc, bt)
            println(stdout)
        end
    end
    if ~isnothing(result)
        set_result(thunk.wrapped_thunk, result)
        return result
    else
        result = reify(thunk.wrapped_thunk)
        reify(thunk.checkpoint)(result)
        return result
    end
end

function reify(value)
    value
end

"Undo function call (non-recursively)"
function undo(thunk::Reversible)
    thunk.result = nothing
    thunk.evaluated = false
    thunk
end

"Undo function call (non-recursively)"
function undo(thunk::WrappedThink)
    undo(thunk.wrapped_thunk)
    thunk
end