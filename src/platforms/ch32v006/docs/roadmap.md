# CH32V006 platform roadmap

The current CH32V006 port is a stable, constrained AOT-only AtomVM tier. This
roadmap explores useful additions without weakening its deterministic build
boundary or exceeding the board's 63,488-byte flash and 8 KiB SRAM budgets.

## Principles

- Keep unsupported BEAM operations as build-time errors.
- Add capabilities independently at compile time where practical, so unused
  runtime code and drivers consume no memory.
- Prefer existing AtomVM APIs when they fit the target.
- Require host validation, flash-size checks, memory-pressure tests, and
  physical-board measurements for every expanded support tier.
- Leave a feature unsupported when it cannot operate reliably within measured
  flash, heap, and C-stack margins.

## Current baseline

The qualified tier provides one embedded RV32E AOT module, one process,
allocation and garbage collection, the documented language subset, polled GPIO,
and a blocking bring-up delay. Native instruction validation, ABI tests, stack
protection, and controlled allocation-failure tests guard this baseline.

See [design.md](design.md#constrained-runtime-boundary) for the exact support
contract.

## Near term

1. **Complete validator qualification.** Exercise all 16-bit compressed
   encodings against an independent RV32EC classification and extend ABI
   regression cases when backend call paths change.
2. **Probe minimal concurrency.** Behind an experimental build option, measure
   the cost of two same-module processes using `spawn/3`, send, receive, and
   reductions-based scheduling. Begin without fun spawning, links, monitors,
   registered names, or SMP.
3. **Decide from hardware measurements.** Concurrency advances only if a
   two-process ping-pong test runs sustainably, allocation failure remains
   controlled, the stack canary retains measured headroom, and representative
   applications fit in flash. Otherwise the stable tier remains single-process.
4. **Add scheduler-aware time.** If concurrency is viable, qualify receive
   timeouts and process timers. The existing blocking delay remains only a
   bring-up helper.
5. **Add bounded binary operations.** Support the smallest construction and
   matching subset needed by practical peripheral APIs, with explicit memory
   limits and negative tests.

## Peripheral expansion

Qualify GPIO interrupts, UART, timers/PWM, ADC, I2C, and SPI independently.
Each driver should be compile-time selectable, follow an existing AtomVM API
where practical, and include a physical-board acceptance application. A small
combined application should be the final integration test.

Peripheral order may follow concrete application needs. Binary and timer
dependencies must be included in each driver's flash and SRAM measurements.

## Later investigations

- Embed and resolve multiple precompiled AOT modules without introducing a
  filesystem or dynamic loader.
- Reassess broader binary and standard-library support after concurrency and
  peripheral measurements.
- Investigate maps or floats only for a demonstrated application requirement.

The BEAM interpreter, standard AVM archive loading, dynamic module loading,
ports, and SMP are not current goals. They should remain unsupported unless a
new implementation can satisfy the same reliability and validation standard.

## Upstream preparation

Keep changes reviewable as RV32E/ILP32E backend support, constrained runtime,
CH32V006 platform support, UIAPduino board configuration, and examples/tests/CI.
Rebase onto the intended upstream branch only when preparing the corresponding
submission.
