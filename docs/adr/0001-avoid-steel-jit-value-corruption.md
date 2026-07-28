# Avoid Steel JIT value corruption

Steel's JIT can corrupt the value returned by an indirect fixed-arity
conversion that reads a struct or list and returns a new struct, as tracked in
[Steel issue 680](https://github.com/mattwparas/steel/issues/680). Keep the JIT
and indirect calls, but move conversions matching that complete shape into
directly called functions. Remove the workaround only after Grove runs a Steel
build with a confirmed fix and the Pointer and Rail acceptance journeys pass.
