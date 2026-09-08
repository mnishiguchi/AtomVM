# ADR 0006: Promote the two-process timer profile

**Status:** Accepted

**Date:** 2026-09-07

## Context

The optional concurrency and timer tiers now have host validation and physical
board evidence for normal operation, memory pressure, allocation-failure
recovery, repeated process cleanup, repeated timeout/message cycles, SysTick
rollover, a natural two-wrap production-timing soak, and a combined GPIO
application. This satisfies the promotion gates in
[ADR 0005](0005-evidence-based-qualification.md) for one bounded
configuration.

The reviewed records cover [external send](../qualification.md#external-send-nif-acceptance--2026-09-07),
the [combined application](../qualification.md#combined-timergpio-application--2026-09-07),
[allocation recovery](../qualification.md#repeated-spawn-oom-recovery--2026-09-07),
[process cleanup](../qualification.md#process-cleanup-stress--2026-09-07),
[timer stress](../qualification.md#timermessage-stress--2026-09-07), and the
[production-timing soak](../qualification.md#production-interval-two-wrap-timer-soak--2026-09-07).

Leaving that configuration labelled experimental would no longer describe its
evidence accurately. Enabling it by default would still spend flash and SRAM
needed by applications that require only the single-process profile.

## Decision

Promote this exact configuration to a stable opt-in runtime profile:

```text
CONCURRENCY=1
TIMERS=1
MAX_PROCESSES=2
C_STACK_RESERVE_BYTES=2048
```

`BINARIES=0` and no optional `PERIPHERALS` are part of this qualified
configuration.

The profile supports:

- the startup process plus at most one child;
- `spawn/3` of an exported function in the single embedded AOT module;
- local-PID send through the BEAM opcode or `erlang:send/2`;
- selective receive and receive timeouts; and
- messages composed of atoms, 28-bit integers, local PIDs, lists, and tuples.

It does not add linked spawning, registered names, aliases, distributed PIDs,
ports, funs, dynamic modules, process timer APIs, or preemptible platform NIFs.
Sending to a dead local PID discards the message and returns it. Invalid
recipients raise `badarg`; allocation failures raise `out_of_memory`.

The single-process profile remains the default. Other process counts, stack
reserves, combinations with byte binaries, and optional peripheral drivers are
separate configurations and are not promoted by this decision.

## Consequences

Users must select the four build values above for the qualified profile, and
the AOT image must carry the matching concurrency and timer variant bits. The
2,048-byte stack reserve reduces allocator capacity, so application-specific
heap and flash measurements remain necessary.

The profile is stable because the named contract has reproducible evidence,
not because it provides general BEAM concurrency parity. Relevant runtime,
toolchain, feature-option, or memory-boundary changes require renewed
qualification under ADR 0005.
