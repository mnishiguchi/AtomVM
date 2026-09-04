# ADR 0002: Define the constrained runtime and memory boundary

**Status:** Accepted

## Context

The 8 KiB SRAM budget must cover static data, AtomVM state, a process heap,
the allocator, and native C stack. A general-purpose AtomVM configuration
cannot fit this target while retaining a useful application surface.

## Decision

Build a deliberately constrained runtime tier: one embedded module/process,
RV32E native execution, selected BIFs, and direct platform NIFs. Reserve
1,432 bytes for the C stack, guard its allocator boundary with a production
canary, and make the reserve configurable for measured board-specific work.

## Consequences

The supported surface includes local calls, tail recursion, allocation and GC,
basic terms and pattern matching, `try/catch`, selected arithmetic BIFs, and
GPIO/delay NIFs. It excludes ports, SMP, dynamic loading, the interpreter, and
the full BIF/NIF/instruction surface.

`ch32v006:delay_ms/1` blocks the one-thread runtime. Any expanded runtime
surface or memory-constant change requires flash checks and renewed physical
board validation.
