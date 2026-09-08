# ADR 0007: Promote the byte-binary profile

**Status:** Accepted

**Date:** 2026-09-08

## Context

The optional binary tier now has host validation and physical-board evidence
for fixed-width byte construction, exact matching, mismatch handling, the
boundary value 255, catchable process-heap exhaustion, and successful
allocation after an injected `out_of_memory` error. A small Elixir packet
application also exercises the same path without test instrumentation.

Negative AOT tests reject operations outside this deliberately narrow subset,
including non-byte and variable-sized segments, binary copying/appending, UTF
segments, and sub-binaries. This satisfies the gates in
[ADR 0005](0005-evidence-based-qualification.md) for one exact configuration.

## Decision

Promote this exact configuration to a stable opt-in runtime profile:

```text
BINARIES=1
CONCURRENCY=0
TIMERS=0
C_STACK_RESERVE_BYTES=1536
PERIPHERALS=
```

It supports fixed-width 8-bit integer binary construction and exact matching of
those binaries. Match failure follows normal control flow. Non-integer segment
values raise catchable `badarg`, and allocation failure raises catchable
`out_of_memory`. Compiler-generated whole-byte literal segments are accepted so
source-level byte sequences can use the same bounded construction path; this
does not enable runtime binary copying or appending.

It does not add variable-sized or non-byte segments, generic runtime segment
flag decoding, binary copying/appending, UTF segments, sub-binaries, floats,
multiple modules, or general binary/bitstring support. AOT generation remains
the authoritative compatibility check and rejects an application that needs an
absent helper.

The single-process profile remains the default. Combining this profile with
concurrency, timers, a different stack reserve, or optional peripherals is a
separate configuration and is not promoted by this decision.

## Consequences

Applications must select `BINARIES=1`, and the AOT image must carry the matching
binary variant bit. Code that is valid BEAM but outside the bounded binary
contract fails at image generation rather than on the device.

The profile is stable because this named subset has reproducible evidence, not
because CH32V006 provides general AtomVM binary parity. Relevant runtime,
precompiler, toolchain, option, or memory-boundary changes require renewed
qualification under ADR 0005.
