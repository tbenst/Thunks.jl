
"Walk an AST and find all unique symbols."
function find_symbols_in_ast(ex)
    # accumulate sub-expressions for recursion
    expressions = [ex]
    # accumulate found symbols
    symbols = []

    # since no Tail Call Optimization in Julia,
    # we write recursion in a while loop
    while length(expressions) > 0
        ex = pop!(expressions)
        first, rest = _find_symbols_in_ast(ex)
        if typeof(first) == Symbol
            # got value, no more recursion
            push!(symbols, first)
        end
        if ~isnothing(rest)
            # recur
            expressions = vcat(expressions, rest)
        end
    end
    return unique(symbols)
end

"Helper function following `cons` and `nil` pattern from Lisp."
function _find_symbols_in_ast(ex)
    if typeof(ex) == Expr
        head, args = ex.head, ex.args
        return nothing, args
    elseif typeof(ex) == Symbol
        return ex, nothing
    else
        return nothing, nothing
    end
end

isthunk(x) = typeof(x) == Thunk

"Safely evaluate symbols that may not have an assignment."
function safe_eval_isthunk(ex)
    try
        return isthunk(eval(ex))
    catch
        return false
    end
end

"Return array of symbols that are assigned to a Thunk."
function find_thunks_in_ast(ex)
    symbols = find_symbols_in_ast(ex)
    filter(safe_eval_isthunk, symbols)
end


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
