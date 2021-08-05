module Thunks
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

#### remaining code in this module pertains to the @thunk macro

"""
Turn expression into a thunk. Supports :call, :(=), :block.

Not intended for public usage.
"""
function thunkify(ex)
    if ex.head == :block
        t = thunkify_block(ex)
    else
        t = _thunkify(ex)
    end
    esc(t)
end

function thunkify_block(ex)
    @assert ex.head == :block "unexpected head ($(ex.head) != :block) for: $ex"
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
    @assert ex.head == :call "unexpected head ($(ex.head) != :call) for: $ex"
    f = ex.args[1]
    :(thunk($f)($(ex.args[2:end]...)))
end

function thunkify_eq(ex)
    @assert ex.head == :(=) "unexpected head ($(ex.head) != :(=)) for: $ex"
    l = ex.args[1]
    if typeof(ex.args[2]) == Expr
        r = thunkify_call(ex.args[2])
    else
        r = ex.args[2]
    end
    :($l = $r)
end

"""
    @thunk

Macro for turning an expression into a thunk. Supports lines like:
```julia
@thunk x+y
@thunk x = f(y)
abc = @thunk begin
    a = 1
    b = 2
    c = 3
    sum([a,b,c])
end
```
"""
macro thunk(ex)
    thunkify(ex)
end

export Thunk, reify, thunk, @thunk
end
