# CH32V006 platform roadmap

Build a useful, predictable constrained AOT-only AtomVM platform within 63,488
flash bytes and 8 KiB SRAM. Basic runtime and peripheral implementations are in
place, and a fixture-free timer-driven LED application establishes the first
combined runtime/driver baseline. The next phase is closing specific validation
gaps and preserving resource margins before extending applications.

The [platform README](../README.md) defines the supported API and build options.
[ADRs](adr/README.md) record architectural decisions.
[Qualification records](qualification.md) retain measured results and their
limitations. Status below was reviewed on 2026-09-08.

## Current capability boundary

| Capability | Evidence so far | Remaining qualification |
| --- | --- | --- |
| Default: one module/process, language subset, polled GPIO | stable baseline, board acceptance | preserve regression coverage |
| 28-bit integer arithmetic | deterministic `overflow`/`badarith`, host checks, and board boundary acceptance | preserve regression coverage |
| Two same-module processes and spawn/send/receive | stable opt-in for `MAX_PROCESSES=2`, timers enabled, and a 2,048-byte stack reserve; board tests include allocation recovery, 256 child lifecycles, and a combined LED application | preserve evidence and measure each application |
| Receive timeouts | stable in the same opt-in profile; board tests include timer/message OOM, 256 cycles, accelerated rollover, a natural two-wrap production-timing soak, and a combined LED application | preserve evidence and measure each application |
| Byte-integer binary construction/exact matching | experimental; board tests including allocation failure and an Elixir packet application | explicit promotion review under ADR 0005 |
| GPIO edge polling | build checks | rising/falling edges and pending-flag clearing |
| UART1 | build checks | PD5/PD6 loopback, no-data and error behavior |
| ADC | board smoke test | known-voltage measurements on PA2/A0 |
| I2C1 | build checks | device read/write, absent device, timeout and bus recovery |
| SPI1 | build checks | PC6/PC7 loopback, device transfer and measured clock |
| TIM1 PWM | board smoke test | measured frequency/duty on PC3/PC4 and GPIO restoration |

Board tests qualify the recorded workload and configuration. They do not
automatically promote a capability to stable or qualify combinations of features.
ADC/PWM smoke tests confirm execution, not electrical accuracy.

Timers require concurrency. Byte binaries and concurrency cannot currently be
combined. Peripheral drivers are independently selected; their synchronous NIFs
block the scheduler. The qualified concurrency workload uses two processes;
raising `MAX_PROCESSES` requires new measurements.

## Next work without external fixtures

Take one bounded change at a time, in this order. Keep the existing host matrix,
exhaustive compressed-instruction checks, ABI canary, negative AOT tests, and
board workloads as regression coverage.

The external `send/2` gap is covered by three Elixir board workloads for OOM
recovery, invalid recipients, and terminated local PIDs. Their builds check the
generated call path; retain them alongside the opcode tests. The first margin
pass moved bounded I2C/SPI results to the process heap and qualified their
64-byte representation on hardware.

The second margin pass replaced generic numeric BIFs with the documented
small-integer-only arithmetic boundary. Out-of-range results now raise
deterministic `overflow`, and the complete OTP 28 matrix retains at least 7,008
flash bytes. The external-send lifecycle image now leaves 10,424 bytes, up from
1,076, while keeping its existing hardware-qualified behavior.

The natural production-timing soak also passed: a 1,432,000 ms receive timeout
crossed two hardware-counter wraps without repositioning SysTick, verified four
production tracking intervals, and delivered a completion message. Keep the
accelerated and natural tests because they cover different failure modes.

The byte-binary application gap is also closed: the minimal Elixir
`BinaryPacket` example constructs and exactly matches a three-byte packet, and
its `BINARIES=1` image passed on the board with 11,912 flash bytes free. Keep
the tier experimental until its evidence is reviewed explicitly against ADR
0005; adding an example alone does not promote it.

### 1. Keep useful resource margins

Compare sizes with the same toolchain, options, and application before and after
each change. Prefer small reductions that preserve failure handling and make
room for a named workload. Keep the 1,024-byte flash gate, stack reserve, and
production canary.

The immediate flash-pressure backlog is closed, but the recovered space is a
budget for useful applications, not permission to broaden the runtime casually.
The default reserve is now 1,536 bytes: the language workload measured 1,268
bytes, leaving 268, while allocator capacity remained 1,576 bytes above its
observed peak. Keep the canary and qualify application-specific overrides; this
measured margin is not a guarantee for arbitrary native call paths. A size
reduction alone does not promote an experimental capability.

### 2. Preserve the stable opt-in concurrency/timer profile

[ADR 0006](adr/0006-promote-two-process-timer-profile.md) promotes only
`CONCURRENCY=1 TIMERS=1 BINARIES=0 MAX_PROCESSES=2
C_STACK_RESERVE_BYTES=2048` without optional peripherals. Keep its variant
checks, allocation-failure recovery, process lifecycle, rollover, production
soak, and combined application in the qualification matrix. Treat a different
process limit, stack reserve, or capability combination as a new configuration
requiring evidence under ADR 0005.

**Done continuously when:** relevant changes rebuild the matrix and renew the
affected board evidence before the profile is described as qualified again.

## Work requiring fixtures

### Qualify the existing peripherals

Start with UART loopback and known-voltage ADC, then SPI/I2C devices, measured
PWM, and GPIO edges as fixtures become available. Cover initialization,
invalid arguments, normal transfers, deadlines, and recovery where applicable.
The current GPIO edge test covers rising edges only; add falling-edge and
clear/re-arm coverage.

**Done when:** each driver has reproducible wiring, expected electrical results,
failure-path checks, and heap/C-stack measurements. UART/I2C/SPI qualification
needs external wiring/devices; keep these gates open until available.

### Extend the useful-application baseline

The fixture-free timer-driven LED state machine combines GPIO, two processes,
messages, and receive timeouts. Its Erlang acceptance image and concise Elixir
example passed on hardware and establish the initial application baseline
without external wiring. Preserve its recovered flash margin, then add a
button-driven or sampled-ADC application after the relevant peripheral is
electrically qualified.

**Done when:** each exact combined image passes host checks and a sustained
board run, has credible flash/heap/C-stack margins, and has reproducible
instructions. Successful individual feature tests do not establish a combined
configuration.

## Promotion and upstream preparation

Promote only the specific configuration that meets
[ADR 0005](adr/0005-evidence-based-qualification.md). Optional capabilities may
remain stable opt-ins; promotion does not require enabling them by default.

Prepare focused changes for RV32E/ILP32E, constrained runtime, CH32V006/UIAPduino,
and tests/examples/CI/docs. Check generic runtime initialization/teardown and
regular backend regressions. Select the upstream base when preparing a
submission; a rebase requires rebuilding and renewed affected qualification.

**Done when:** the capability contract matches evidence and each submission is
independently reviewable with appropriate regression tests.

## Keep evidence useful

Preserve each image's `.build-info.txt` with board output and the details in
[qualification records](qualification.md#reproduce-and-record-a-run). Record
historical reruns when they close an active qualification gap. Host rebuilds
do not renew hardware evidence.

After a milestone, update the capability row and next action here; keep test
narratives and changing measurements in qualification records. Change an ADR
only for a durable decision or a clarification of its scope. If progress needs
unavailable wiring, leave that gate open and select work above that needs no
fixture. New capabilities need an application use case and a measured budget.

## Deferred until an application needs them

- Multiple embedded AOT modules: first measure metadata, import resolution,
  flash, and SRAM cost; update ADR 0001 if adopted.
- More processes, maps, floats, broader binaries, or library functions: require
  a concrete use case, deterministic feature validation, and measured fit.
- API alignment with larger AtomVM platforms: reuse semantics where practical
  without assuming port-based APIs fit.

The interpreter, AVM archive loading, dynamic loading, ports, SMP, and complete
ESP32 feature parity are outside the current plan. No milestone requires every
optional feature to fit simultaneously.
