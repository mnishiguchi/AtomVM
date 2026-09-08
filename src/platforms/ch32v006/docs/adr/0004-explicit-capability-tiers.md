# ADR 0004: Add capabilities as explicit build-time tiers

**Status:** Accepted

**Date:** 2026-09-04

**Clarified:** 2026-09-07 by [ADR 0005](0005-evidence-based-qualification.md).

## Context

Concurrency, timers, binaries, and peripheral drivers are useful, but enabling
all of them would exceed the CH32V006 flash budget and obscure the stable
runtime contract. Native AOT code also calls helpers by interface offset, so a
feature mismatch must not reach the device.

## Decision

- Keep the default image as the qualified single-process, polled-GPIO tier.
- Give optional runtime capabilities distinct native-image variant bits.
- Reject unsupported target/variant combinations during AOT generation.
- Select peripheral drivers independently at compile time.
- Qualify each tier with its own application, native-code validation, flash-size
  check, and physical-board test.
- Keep a tier experimental until an explicit promotion review confirms the
  qualification gates in ADR 0005. A passing board self-test alone is
  insufficient; the supported configuration and limits must also be documented.

Peripheral experiments may use small direct NIFs when AtomVM's normal
port-based API is too expensive. Such APIs are platform-specific until proven
compatible and affordable.

## Consequences

Applications must select matching runtime tiers when building the AOT image
and runtime; a native-variant mismatch is rejected at startup. Peripheral
selection does not have its own variant bits. Calls to unselected peripheral
NIFs follow the catchable `undef` behavior in ADR 0003, so a matching variant
alone does not establish that every application import is available.

Features can advance independently, and an experiment that fails the memory
gates does not weaken the stable tier. Each useful combination needs its own
integration qualification. A passing combined application establishes evidence
for that configuration; it does not imply that all optional tiers fit together.
