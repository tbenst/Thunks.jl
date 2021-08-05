module Thunks

mutable struct Thunk
    f::Any # usually a Function, but could be any callable
    args::Tuple
    kwargs::Dict # not supported yet
    evaluated::Bool
    result::Any
    Thunk(f, args, kwargs) = new(f, args, kwargs, false, nothing)
end

function thunk(f; kwargs...)
    (args...) -> Thunk(f, args, kwargs)
end



"""
    reify(thunk::Thunk)

Reify a thunk into a value.

Walk through the thunk's arguments, recursively evaluating each one,
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

"Turn expression into a thunk. Supports :call, :(=), :block."
function thunkify(ex)
    if ex.head == :block
        t = thunkify_block(ex)
    else
        t = _thunkify(ex)
    end
    esc(t)
end

function thunkify_block(ex)
    @assert ex.head == :block
    args = map(_thunkify, ex.args)
    Expr(:block, args...)
end

function _thunkify(ex)
    if typeof(ex) == Expr
        if ex.head == :call
            thunkify_call(ex)
        elseif ex.head == :(=)
            thunkify_eq(ex)
        end
    else
        # e.g. for LineNumberNode in a block
        ex
    end
end

function thunkify_call(ex)
    @assert ex.head == :call
    f = ex.args[1]
    :(thunk($f)($(ex.args[2:end]...)))
end

function thunkify_eq(ex)
    @assert ex.head == :(=)
    l = ex.args[1]
    if typeof(ex.args[2]) == Expr
        r = thunkify_call(ex.args[2])
    else
        r = ex.args[2]
    end
    :($l = $r)
end

macro thunk(ex)
    thunkify(ex)
end

export Thunk, reify, thunk, @thunk
end
