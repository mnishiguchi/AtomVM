# ADR 0004: Add capabilities as explicit build-time tiers

- Status: accepted
- Date: 2026-09-04

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
- Call a tier experimental until its final image has passed the hardware test
  and its heap and C-stack margins have been measured.

Peripheral experiments may use small direct NIFs when AtomVM's normal
port-based API is too expensive. Such APIs are platform-specific until proven
compatible and affordable.

## Consequences

Applications must opt into every non-baseline capability when building both the
AOT image and runtime. A mismatched image is rejected at startup. Features can
advance independently, and an experiment that fails the memory gates does not
weaken the stable tier.

The combined integration application remains a final qualification milestone,
not a promise that every optional tier can fit simultaneously.
