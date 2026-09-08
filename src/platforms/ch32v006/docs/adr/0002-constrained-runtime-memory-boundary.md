# ADR 0002: Define the constrained runtime and memory boundary

**Status:** Accepted

## Context

The 8 KiB SRAM budget must cover static data, AtomVM state, a process heap,
the allocator, and native C stack. A general-purpose AtomVM configuration
cannot fit this target while retaining a useful application surface.

## Decision

Build a deliberately constrained default runtime tier: one embedded module and
process, RV32E native execution, selected BIFs, and direct platform NIFs. Reserve
1,536 bytes for the C stack, guard its allocator boundary with a production
canary, and make the reserve configurable for measured board-specific work.

The original 1,432-byte bring-up value left 164 measured bytes under the
language acceptance workload. The 1,536-byte default raises that margin to 268
bytes while leaving 1,576 allocator bytes above the workload's observed peak.

Optional capabilities follow [ADR 0004](0004-explicit-capability-tiers.md).
The two-process experiment extends the default process limit without changing
the one-module firmware model. Memory-pressure tests use a 2,048-byte stack
reserve, reducing the allocator budget accordingly.

## Consequences

The supported surface includes local calls, tail recursion, allocation and GC,
basic terms and pattern matching, `try/catch`, selected arithmetic BIFs, and
GPIO/delay NIFs. It excludes ports, SMP, dynamic loading, the interpreter, and
the full BIF/NIF/instruction surface.

Arithmetic remains inside the immediate 28-bit signed-integer boundary.
Out-of-range results raise `overflow` rather than linking boxed/big-integer and
floating-point arithmetic into this tier.

`ch32v006:delay_ms/1` blocks the one-thread runtime. Any expanded runtime
surface or memory-constant change requires flash checks and renewed physical
board validation.

The canary detects corruption when checked; it does not prevent native stack
growth into the allocator. Measured high-water marks apply to the exercised
paths, not arbitrary applications. Keep allocation failures controlled and
test recovery where the operation is documented as catchable.
