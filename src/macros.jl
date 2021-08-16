
"""Walk an AST and find all unique symbols.
"""
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

# https://docs.julialang.org/en/v1/base/base/#Keywords
RESERVED = [
    :baremodule, :begin, :break, :catch, :const, :continue, :do, :else,
    :elseif, :end, :export, :false, :finally, :for, :function, :global, :if,
    :import, :let, :local, :macro, :module, :quote, :return, :struct, :true,
    :try, :using, :while
]
"Return true if symbol could be assigned to a Thunk."
function maybe_thunk(symbol, ignore_symbols)
    # println("maybe_thunk: $symbol")
    if symbol in RESERVED
        ret = false
    elseif symbol in ignore_symbols
        ret = false
    elseif string(symbol)[1] == '.'
        # ie .+ is not a possible thunk
        ret = false
    else
        ret = true
    end
    # println("maybe_thunk: $symbol, $ret")
    ret
end

"""
We find all "assigned symbols", as in, everything except:
- anonymous functions :((x,y,z) -> x*x).args[1]
- generators :((x for x in 1:10))
- Reserved keywords
- ... others that we should catch...?
"""
function find_assigned_symbols_in_ast(ex)
    # accumulate sub-expressions for recursion
    # println("===== intitial call ========")
    expressions = [ex]
    # paired list of symbols to ignore per expression
    ignore_sym_per_ex = [Vector{Symbol}()]

    # accumulate found symbols
    symbols = Vector{Symbol}()

    while length(expressions) > 0
        # @show expressions
        # @show ignore_sym_per_ex
        # @show symbols
        ex = pop!(expressions)
        ignore_symbols = pop!(ignore_sym_per_ex)
        if (typeof(ex) == Expr)
            if ex.head == :->
                # anonymous function, so need to ignore unassigned symbols
                ignore_symbols = vcat(ignore_symbols, find_symbols_in_ast(ex.args[1]))
                first, rest = _find_symbols_in_ast(ex.args[2])
            elseif ex.head == :generator
                # right hand of generator, first arg is the assignment
                ignore_symbols = vcat(ignore_symbols, ex.args[2].args[1])
                first, rest = _find_symbols_in_ast(ex)
            else
                first, rest = _find_symbols_in_ast(ex)
            end
        else
            first, rest = _find_symbols_in_ast(ex)
        end

        # 0 or 1 of next if blocks will be executed

        if typeof(first) == Symbol
            # got value, no more recursion
            if maybe_thunk(first, ignore_symbols)
                push!(symbols, first)
            end
        end

        if ~isnothing(rest)
            # recur
            expressions = vcat(expressions, rest)
            ignore_sym_per_ex = vcat(ignore_sym_per_ex,
                repeat([ignore_symbols], length(rest)))
        end
    end
    unique(symbols)
end

"""
Return either (nothing, List[Expr]), (Symbol, nothing), or (nothing, nothing).

Helper function following `cons` and `nil` pattern from Lisp.
"""
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


"""
Rewrite expression for lazy evaluation using thunks.
Not intended for public usage.
"""
function thunkify(ex, type=Thunk)
    if ex.head == :block
        t = thunkify_block(ex, type)
    else
        t = _thunkify(ex, type)
    end
    t
end

"Rewrite a begin...end block to be lazy."
function thunkify_block(ex, type=Thunk)
    @assert ex.head == :block "unexpected head ($(ex.head) != :block) for: $ex"
    args = map(t -> _thunkify(t,type), ex.args)
    Expr(:block, args...)
end

"Assign left of `=` to a thunk."
function _thunkify_eq(ex, type=Thunk)
    @assert ex.head == :(=) "unexpected head ($(ex.head) != :(=)) for: $ex"
    l = ex.args[1]
    if typeof(ex.args[2]) == Expr
        # recursion...
        r = thunkify(ex.args[2], type)
    else
        r = ex.args[2]
    end
    :($l = $r)
end

"""Actually create the Thunk struct.

Wrap expression in anonymous function, with each assigned symbol as an arg.
"""
function _thunkify_expr(ex, type=Thunk)
    symbols = find_assigned_symbols_in_ast(ex)
    vars = "("
    for sym in symbols
        vars *= "$sym,"
    end
    vars *= ")"
    vars = Meta.parse(vars)
    wrapped = :($vars -> $ex)
    if type == Thunk
        Expr(:call, Thunk, wrapped, vars)
    elseif type == Unevaluated
        vars = :(() -> $vars)
        Expr(:call, Unevaluated, wrapped, vars)
    else
        error("_thunkify_expr not implemented for type: $type")
    end
end

"Helper function to dispatch based on Expr head."
function _thunkify(ex, type=Thunk)
    if typeof(ex) == Expr
        if ex.head == :(=)
            _thunkify_eq(ex, type)
        else
            _thunkify_expr(ex, type)
        end
    else
        # e.g. for LineNumberNode in a block
        ex
    end
end

"""
    @lazy <Expr>

Lazy evaluation of arbitrary expressions.
```julia
@lazy x+y
@lazy x = f(y)
@lazy begin
    a = 1
    b = 2
    c = 3
    abc = sum([a,b,c])
end
reify(abc)
# output
6
```
"""
macro lazy(ex)
    new = thunkify(ex, Thunk)
    esc(new)
end


"""
    @noeval <Expr>

Lazy evaluation of arbitrary expressions that does not check for variable
definition. This is safe to use if the assumption of referential transprency
holds, and should be used with extreme caution otherwise, e.g. if referenced
variables might be mutated. Note that evaluation occurs in the scope of where
`reify` is called.

```jldoctest
@noeval begin
    # will not error
    not_used = not_defined + 1
    a = 1
    b = 2
    c = 3
    abc = sum([a,b,c])
end
c = -1
reify(abc)
# output
2
```
"""
macro noeval(ex)
    new = thunkify(ex, Unevaluated)
    esc(new)
end