# CH32V006 qualification records

Measured evidence supporting the [roadmap](roadmap.md), separate from the
[qualification policy](adr/0005-evidence-based-qualification.md).

Earlier baseline records lack complete commit/toolchain/checksum manifests;
new entries include build identity. None establish that a later rebuild has
passed on hardware. Dates are given only where recorded.

## Reproduce and record a run

From the platform directory, run the host validation and image matrix:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun clean
make CH32FUN=/path/to/ch32fun/ch32fun qualification-images
```

This builds and validates images; it does not flash or test the board. The CI
workflow separately builds release, Elixir example, and external-send acceptance
images. For flashing and monitoring, follow [getting started](getting-started.md).

Each `image` and `release-image` build writes a sibling `.build-info.txt` with
BIN/ELF/input/embedded-BEAM checksums, source revisions and working-tree status,
compiler/OTP versions, and build options. Keep it with the board output. It
records a host build only; `hardware_test=not-recorded` is intentional.
Dirty or non-Git source trees need a separately preserved source snapshot.
For an imported BEAM, record its original build command and Elixir version
separately; the firmware build cannot infer them from its checksum.

For each new hardware result, record:

- date, AtomVM commit (and any local changes), ch32fun revision, and compiler/OTP
  versions, plus Elixir version when used;
- image name and SHA-256, build command/options, and flash bytes remaining;
- board revision, wiring/fixture, expected result, and observed output;
- run duration/cycle count, allocator peak, process-heap figures, C-stack
  peak/reserve, and stack-guard result;
- instrumentation differences from production (timing intervals, stack reserve,
  and fault injection), completion condition, and external timeout;
- failures exercised, recovery observed, and anything still untested.

Keep host rebuilds distinct from board runs. Rerun affected hardware tests after
changes to their runtime or driver paths. Preserve earlier observations with
their original image sizes rather than updating them to match a new build.

## Default C-stack reserve — 2026-09-08

The default C-stack reserve increased from 1,432 to 1,536 bytes after the
language workload measured only 164 bytes of headroom. The extra 104 bytes come
from the native allocator region; firmware sizes are unchanged.

The images were built from AtomVM
`ffbcf4ebe869f17f227f052b0006328e561ddc3b` with this change uncommitted,
clean ch32fun `618bba58c615ed29dc99e6ea92d869c914b6a8c0`, GCC 14.2.0, and
OTP 28.5.0.1 / ERTS 16.4.0.1. No external wiring was used.

| Board image | Bytes / free | Result | Allocator used / capacity / peak | Process heap words / free | C-stack peak / reserve |
| --- | --- | --- | --- | --- | --- |
| language regression | 51,116 / 12,372 | passed, final `ok` | 4,480 / 6,232 / 4,656 | 66 / 5 | 1,268 / 1,536 |
| process-heap OOM | 47,924 / 15,564 | caught OOM, passed, final `ok` | 4,760 / 6,232 / 5,240 | 169 / 6 | 660 / 1,536 |
| arithmetic boundary | 56,480 / 7,008 | passed, final `ok` | 4,456 / 6,232 / 4,464 | 39 / 26 | 948 / 1,536 |
| initial-process OOM | 46,924 / 16,564 | injected allocation failure passed, final `ok` | not available | not available | guard intact |

The language workload now leaves 268 measured C-stack bytes and 1,576
allocator bytes above its peak. The process-heap OOM workload reached a higher
5,240-byte allocator peak, recovered cleanly, and retained 992 bytes. These are
workload-specific measurements, not a general stack or heap guarantee.

The complete 29-image Erlang qualification matrix passed AOT, opcode,
native-instruction, native-variant, ELF ABI, and flash checks with the new
default. SHA-256 identities, in table order:

```text
f36a8d1fef77b79c9a13b4505dbe80f4e215a06d7654146d06d62650caefb7b9
d900d3c3abadf62fcc31ec6686b29d224b8701463fd8a6795a834b15bdfd4825
afb6e7bed79caf91960c3847228b52e9f61e2ba3c6e8bf93811a2cb0e3cd74f6
69651ce9cd6f6aa5fcbe1640ae32bd9c23f39791ac36225f8161f4a374260752
```

## Small-integer arithmetic boundary — 2026-09-08

The constrained runtime now uses dedicated `+`, `-`, `*`, `div`, and `rem`
handlers for immediate 28-bit signed integers. They raise `overflow` when a
result cannot remain immediate and `badarith` for invalid operands or a zero
divisor, without linking generic boxed/big-integer and floating-point arithmetic.

`arithmetic-boundary-image` obtains the maximum immediate integer through a
test-only NIF so OTP cannot fold the boundary expressions. Its build also
requires all five arithmetic operations in the disassembled BEAM before AOT.
The test covers addition, subtraction, multiplication, the minimum integer
divided by `-1`, and its defined zero remainder.

The image was built from AtomVM `933f962cfb216e2ce5a080693f3c88a70e42663d`
with this change uncommitted, clean ch32fun
`618bba58c615ed29dc99e6ea92d869c914b6a8c0`, GCC 14.2.0, and OTP 28.5.0.1 /
ERTS 16.4.0.1. No external wiring was used.

| Board image | Bytes / free | Result | Allocator used / capacity / peak | Process heap words / free | C-stack peak / reserve |
| --- | --- | --- | --- | --- | --- |
| arithmetic boundary | 56,480 / 7,008 | passed, final `ok` | 4,456 / 6,336 / 4,464 | 39 / 26 | 948 / 1,432 |
| language regression | 51,116 / 12,372 | passed, final `ok` | 4,480 / 6,336 / 4,656 | 66 / 5 | 1,268 / 1,432 |
| combined timer/GPIO | 52,836 / 10,652 | passed, final `ok` | 4,248 / 5,712 / 4,544 | 18 / 4 | 888 / 2,048 |

The stack guard remained intact in all runs. The language result leaves only
164 measured C-stack bytes, so this flash reduction does not justify reducing
the stack reserve. SHA-256 identities, in table order:

```text
source 97ce54712b516a5c65dc042ffdd921bc34823fbfc4bcd05e325c7269d77ffd1f
BIN    8c93741e730d1bcee5d67d32fbcd8bf82d737e85fdcf50a2fb274758918e7ecb
BIN    bd7aa901576dfb7fb7cdfbed2c1831232a07d3913b14581c31fd95105d35856f
BIN    2dc0bc551730aee806e326a7bcdd51f130613cfdd91bcfbb1c7009cdca43674b
```

The complete Erlang qualification matrix and the three Elixir external-send
images passed AOT, generated-instruction, native-variant, ELF ABI, and flash
checks with the same toolchain. Generic AtomVM's unmodified arithmetic path was
also rebuilt by compiling the ordinary `libAtomVM` target without the CH32V006
feature macro.

## External send NIF acceptance — 2026-09-07

Three Elixir images passed on the UIAPduino Pro Micro CH32V006 v1.1 without
external wiring. Their generated BEAM contains external `erlang:send/2` calls
and no send opcode; this is checked before AOT generation and in CI.

- `external-send-image`: one injected mailbox allocation failure raises
  `out_of_memory`; the next self-send returns `ping` and delivers it.
- `external-send-lifecycle-image`: a child sends its PID and exits. A successful
  replacement spawn under the two-process limit proves the original slot was
  reclaimed; sending to the old PID returns `discard`.
- `external-send-badarg-image`: a non-PID recipient raises catchable `badarg`.

Build from the platform directory with:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun \
  external-send-image external-send-lifecycle-image external-send-badarg-image
```

Each target compiles its matching `tests/ch32v006_external_send*_self_test.ex`
with `elixirc`. The AtomVM runtime was unchanged from
`89bc3071dd9a86ff2d8582a5c29b6735c8b30b5f`; the acceptance sources, Makefile,
and CI integration were uncommitted at build time. Toolchain: Elixir 1.19.5,
OTP 28.5.0.1 / ERTS 16.4.0.1, GCC 14.2.0, and clean ch32fun
`618bba58c615ed29dc99e6ea92d869c914b6a8c0`.

All three use `CONCURRENCY=1 TIMERS=0 BINARIES=0 MAX_PROCESSES=2`, no optional
peripherals, a 2,048-byte stack reserve, and the 1,024-byte flash-headroom gate.
Acceptance diagnostics enable stack painting and 10 ms SysTick tracking;
only the OOM image enables allocator fault injection. These are finite
acceptance workloads, not a production-timing soak.

Each 10-second terminal capture contained `SysTick time ok`, `RV32E ABI ok`,
`AtomVM self-test: passed`, and final `ok`, including the production stack-guard
check. The OOM run also printed the expected `mailbox.c:273` allocation failure.
Elapsed workload durations were not independently measured. The monitor's
external timeout ended capture after completion; it was not the pass signal.

| Image suffix | Flash bytes / free | Allocator used / capacity / peak | Process heap words / free | C-stack peak / reserve |
| --- | --- | --- | --- | --- |
| external-send-self-test | 61,844 / 1,644 | 4,240 / 5,696 / 4,240 | 11 / 6 | 668 / 2,048 |
| external-send-lifecycle-self-test | 62,412 / 1,076 | 4,272 / 5,704 / 4,568 | 14 / 1 | 672 / 2,048 |
| external-send-badarg-self-test | 60,620 / 2,868 | 4,184 / 5,704 / 4,184 | 8 / 6 | 672 / 2,048 |

Image names use the prefix `AtomVM-uiapduino-pro-micro-ch32v006-` and `.bin`.
SHA-256 identities, in the same order as the table:

```text
source ec949e881653f75ca85162affe88edfb9d47695c240bd5b68c51bc3e876c80cc
BEAM   d6baa2f23b9015f388a3f2d9a8b1df43356f2389292d55de545b2d6deaf2d11c
BIN    46040778e67c5001ae8de1cd9d36a497b265153641c349b637f03952a5fe6e48

source eea48e84589120a691852e9b8b5ffabc5aa87154e7d7074792d7834da125ac3b
BEAM   a6c8687e6c9151bc39a080d2393c54bf7878a988a0cc2c08ad9264a3db1066e9
BIN    9fa88014dadadb55d76f42bd61a92e3ff952d02e1e273c2c5ed4e0517a128df7

source da0b61b518060e051b84c7ef591a6d0ccee2e609388188dacea445ef689f09e2
BEAM   cc465e8fab4409da8ce90abaab09cc0b98d44443a0848b627a7af210a44e93f5
BIN    12c225106c1d49724cb39068e176447f7ec5d0c0dd5313bde1188945207904f4
```

All images passed AOT, machine-code, ELF ABI, and flash checks. The lifecycle
image has only 52 bytes above the flash policy; keep these workloads separate.
These results qualify the listed atom-message cases, not sustained recovery,
arbitrary message sizes, or promotion of the concurrency tier.

## Production-interval two-wrap timer soak — 2026-09-07

`timer-production-soak-image` passed on the UIAPduino Pro Micro CH32V006 v1.1
without external wiring. Its child uses a 1,432,000 ms receive timeout, just
beyond the approximately 1,431,656 ms required for two 32-bit SysTick wraps at
the default 48 MHz clock and HCLK/8 SysTick rate. It then checks that four
production tracking interrupts completed and monotonic time crossed the
two-wrap boundary before sending a completion message to its parent.

The image was built from AtomVM `a6a485b2`, with the soak change uncommitted,
and clean ch32fun `618bba58c615ed29dc99e6ea92d869c914b6a8c0`. Toolchain: GCC
14.2.0 and OTP 28.5.0.1 / ERTS 16.4.0.1. Options:
`CONCURRENCY=1 TIMERS=1 MAX_PROCESSES=2`, no optional peripherals, 2,048-byte
stack reserve, and the 1,024-byte flash-headroom policy. The 61,092-byte image
left 2,396 flash bytes.

- Source SHA-256:
  `9de322a8996285d3f35a9028e43c1a9f4c50f156132ddf231f9e0da695b1789b`.
- BIN SHA-256:
  `21f3624e32d0a024b438ea61d56746a5b9ad1b3cdf9474613721a219e507af77`.
- Completion condition: child readback succeeds, its exact PID-tagged message
  reaches the parent, and the image prints final `ok`.
- External timeout: 1,500 seconds. The parent has a 1,437,000 ms failure
  timeout, five seconds longer than the child.

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4072/5704 bytes, peak 4368
AtomVM process heap: 14 words, 4 free
AtomVM C stack peak: 652/2048 bytes
ok
```

The final `ok` includes the production stack-guard check. The child delay
defines a minimum workload duration of 1,432 seconds; elapsed wall time was not
independently measured. The result arrived before the 1,500-second monitor
timeout, which then ended the terminal capture.

Unlike the accelerated rollover image, this build retains the production
357,913 ms tracking interval and does not reposition or stop SysTick. Test-only
differences are the pass/readback NIF, self-test reporting and stack painting,
and the 2,048-byte stack reserve. There is no fault injection. This result
qualifies the exercised two-process timer/message configuration across two
natural wraps; it does not establish arbitrary application duration or memory
capacity.

## Bounded peripheral result binary — 2026-09-07

`io-binary-image` passed on the UIAPduino Pro Micro CH32V006 v1.1 without
external wiring. A test-only NIF uses the same production helper as I2C and SPI
to create a 64-byte result, fills it with values 0 through 63, and returns it
through the native/BEAM boundary. A second NIF verifies that it remains a heap
binary with the expected size and every byte intact.

The current test also copies that input after a forced garbage collection and
verifies both values. This covers the rooted allocate-while-input-is-live path
used by SPI transfer without requiring an electrical bus fixture.

The image was built from AtomVM `23608c6f`, with this change uncommitted, and
clean ch32fun `618bba58c615ed29dc99e6ea92d869c914b6a8c0`. Toolchain: GCC
14.2.0 and OTP 27 / ERTS 15.2.7. Options: `PERIPHERALS=i2c`, default runtime,
1,432-byte stack reserve, and 1,024-byte flash-headroom policy. The 59,156-byte
image left 4,332 flash bytes.

- Source SHA-256:
  `753b7dfe772474be4b10e3504d81f3234f60bc462a7d604a09e3666952f56cb7`.
- BIN SHA-256:
  `5b68508a814cc26bcee7da0a53b8cbb730aef837cb01fd72dc8ad1d91d8ee8da`.
- Completion condition: `AtomVM self-test: passed` and final `ok` within a
  10-second monitor capture.

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4144/6320 bytes, peak 4184
AtomVM process heap: 42 words, 23 free
AtomVM C stack peak: 660/1432 bytes
ok
```

The historical final `ok` above includes the production stack-guard check. It
verified the bounded binary representation and native boundary before the
forced-GC copy was added; the renewed result is recorded below. Neither run
qualifies I2C/SPI electrical transfers and their failure paths.

The forced-GC version passed on the board on 2026-09-08 with both the local OTP
27 build and the OTP 28 build used by CI. Both were built from AtomVM
`c2c2b15bf86be1a0582b20a903432051f9b82577` with the test and related
documentation uncommitted, clean ch32fun
`618bba58c615ed29dc99e6ea92d869c914b6a8c0`, and GCC 14.2.0. Each image was
50,252 bytes and left 13,236 flash bytes. Their SHA-256 values were
`746251da0336c57c37301fbac5c619ab3748aeef6ab56e9e5e12532e4444a5b0` for OTP
27 / ERTS 15.2.7 and
`9a6e111d0b43e9544eabd62dfa6ce1c80d91f0ddc037d280433cc1a48bc3a664` for OTP
28.5.0.1 / ERTS 16.4.0.1.

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4216/6224 bytes, peak 4392
AtomVM process heap: 52 words, 14 free
AtomVM C stack peak: 660/1536 bytes
ok
```

The renewed workload retained 1,832 allocator bytes above peak and 876 bytes
of measured C-stack headroom. Its forced collection is test-only; production
SPI transfer uses ordinary allocation pressure but the same rooted helper.

With the same source, build options, GCC, and OTP 27, the I2C image decreased
from 62,456 to 62,220 bytes. The directly comparable OTP 28 measurement
decreased from the previously recorded 62,460 bytes to 62,224, leaving 1,264
bytes. The OTP 28 SPI image is 60,844 bytes, leaving 2,644. The complete OTP 27
peripheral matrix passed its AOT, native-instruction, ELF ABI, and flash checks.

## Combined timer/GPIO application — 2026-09-07

The fixture-free combined self-test passed on the UIAPduino Pro Micro CH32V006
v1.1. A child process toggled the onboard PC3 LED eight times at 100 ms
intervals using receive timeouts, then sent its PID to the parent. The parent
verified the reply and reported success. This exercises GPIO together with two
processes, scheduler timers, and message delivery; it does not electrically
measure the LED waveform.

Build identity:

- AtomVM base: `2ae7b16fe5de486fb2a7a0a2ffc7c702db8d39db`, with this change set
  uncommitted at build time.
- Test source SHA-256:
  `cb2a7cb31bc0d6dad54a95808ddb026de2162004ae283c1a3eec61651c28bcff`.
- ch32fun: `618bba58c615ed29dc99e6ea92d869c914b6a8c0`, clean checkout.
- GCC: `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0`; OTP 27, ERTS
  15.2.7.12.
- Options: `CONCURRENCY=1 TIMERS=1 MAX_PROCESSES=2 C_STACK_RESERVE_BYTES=2048`,
  no optional peripherals, default 1,024-byte minimum flash headroom.
- Image: `AtomVM-uiapduino-pro-micro-ch32v006-combined-self-test.bin`; 62,224
  bytes, leaving 1,264 flash bytes.
- BIN SHA-256:
  `600cb8a790f9abdd8f17bf08e57cf3db03a6e67b02894d878ce98620c54bb147`.
- Fixture: no external wiring; the onboard PC3 LED is the application output.

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4248/5704 bytes, peak 4544
AtomVM process heap: 18 words, 4 free
AtomVM C stack peak: 864/2048 bytes
ok
```

The final `ok` includes the production stack-guard check. Peak allocator
headroom was 1,160 bytes and measured C-stack headroom was 1,184 bytes.

The corresponding `TimerBlink.ex` application was compiled with Elixir 1.19.5
and OTP 28.5.0.1, then AOT-compiled with the same concurrency/timer tier and the
normal 1,432-byte stack reserve. It passed on the same board and printed
`AVM CH32V006 boot` followed by `ok`. The source SHA-256 was
`e9160f611e82b20458b7d9119a929e051d36cfb0f60e6dd2ae6318fd09ae7c1b`;
the generated BEAM SHA-256 was
`b359dfb07fa1040215fdaffecf998c5ff61b647f4531d019442035f571f99509`.
Its 62,196-byte image left 1,292 flash bytes and had BIN SHA-256
`a63cf13a7addbd1cb7c09b1edea80de75a11f2b156f8bf438752554b583861c8`.
The CI size gate protects its 268-byte margin above the 1,024-byte policy.

## Accelerated SysTick rollover — 2026-09-07

`timer-wrap-image` passed on the UIAPduino Pro Micro CH32V006 without external
wiring. A test-only NIF stops SysTick with interrupts disabled, preserves the
prior interrupt state, places its 32-bit counter 30 ms before rollover, resets
the software extension, schedules the next 10 ms tracking interrupt, and
restores SysTick. A 50 ms receive timeout spans zero. The test then verifies the
hardware counter wrapped and monotonic time advanced by at least 40 ms before a
second timed child message exchange.

Build identity:

- AtomVM base: `a7a091e9062f9b238b2f57e0cbaf63477ab530b4`, with the rollover test
  and its guarded helpers uncommitted at build time.
- Test source SHA-256:
  `0af99510f56cd81a33d2d46b798420967383a4e6d52b63c8375197be2cc9c458`.
- ch32fun: `618bba58c615ed29dc99e6ea92d869c914b6a8c0`, clean checkout.
- GCC: `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0`; OTP 27, ERTS 15.2.7.
- Options: `CONCURRENCY=1 TIMERS=1 MAX_PROCESSES=2 C_STACK_RESERVE_BYTES=2048`,
  no optional peripherals, default 1,024-byte minimum flash headroom.
- Image: `AtomVM-uiapduino-pro-micro-ch32v006-timer-wrap-self-test.bin`;
  61,840 bytes, leaving 1,648 flash bytes.
- BIN SHA-256:
  `9cb0b3ef747718a1cebd3db6fd6103196a82212522d1aaa3757d61bb69976021`.

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4128/5696 bytes, peak 4696
AtomVM process heap: 14 words, 4 free
AtomVM C stack peak: 652/2048 bytes
ok
```

The final `ok` includes the rollover assertions and production stack-guard
check. Peak allocator headroom was 1,000 bytes and measured C-stack headroom
was 1,396 bytes. Self-test firmware tracks SysTick every 10 ms; production
firmware uses a much longer interval. This proves the hardware rollover and
scheduler path, but a production-interval real-time soak remains separate.

A separate OTP 28.5.0.1 build passed AOT, instruction, ABI, and flash checks at
61,848 bytes (1,640 free). Its BIN contains the exact generated BEAM and ABI
canary. It was not flashed; the board result above belongs to the OTP 27 image.

## Repeated spawn-OOM recovery — 2026-09-07

`process-oom-stress-image` passed on the UIAPduino Pro Micro CH32V006 without
external wiring. Each of 64 cycles injects failure into `context_new()`, expects
catchable `out_of_memory`, then successfully spawns a child, receives its PID,
allows it to terminate, and reuses the process slot. Exactly 64 expected
allocation diagnostics were captured. This exercises repeated cleanup after
failed and successful spawns; it does not inject failures later in child setup.

Build identity:

- AtomVM base: `a0b31b02fcf633bda18828934fe1d17361fdb798`, with the new test and
  Makefile integration uncommitted at build time.
- Test source SHA-256:
  `59027ace55c4cc4eca69230af43737de6fa5da54a83928d027817bba716db0e8`.
- ch32fun: `618bba58c615ed29dc99e6ea92d869c914b6a8c0`, clean checkout.
- GCC: `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0`; OTP 27, ERTS 15.2.7.
- Options: `CONCURRENCY=1 TIMERS=1 MAX_PROCESSES=2 C_STACK_RESERVE_BYTES=2048`,
  no optional peripherals, default 1,024-byte minimum flash headroom.
- Image: `AtomVM-uiapduino-pro-micro-ch32v006-process-oom-stress-memory-pressure-self-test.bin`;
  61,136 bytes, leaving 2,352 flash bytes.
- BIN SHA-256:
  `15c4d6e72f0d1ada5fa168d801e71b19597ff173a04309f91e27afb1c68e8fc0`.

The final target produces the same configuration under the shorter
`process-oom-stress-self-test` image name. The terminal was captured for 50
seconds because printing 64 expected diagnostics dominates the runtime.

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
[64 expected context.c:69 allocation diagnostics]
AtomVM self-test: passed
AtomVM heap: 4224/5696 bytes, peak 4520
AtomVM process heap: 41 words, 34 free
AtomVM C stack peak: 652/2048 bytes
ok
```

The final `ok` includes the production stack-guard check. Peak allocator
headroom was 1,176 bytes and measured C-stack headroom was 1,396 bytes. These
margins apply only to this test and configuration.

A separate OTP 28.5.0.1 build passed AOT, instruction, ABI, and flash checks at
61,144 bytes (2,344 free). Its BIN contains the exact generated BEAM and ABI
canary. It was not flashed; the board result above belongs to the OTP 27 image.

## Process cleanup stress — 2026-09-07

`process-stress-image` passed on the UIAPduino Pro Micro CH32V006 with no
external wiring. It creates 256 short-lived children, verifies each PID/sequence
reply, and reuses the two-process capacity. Each spawn is bounded to 20 attempts
with 1 ms receive waits after `system_limit`; each reply has a 200 ms deadline.
It does not inject allocation faults or test SysTick wraps.

Build identity:

- AtomVM base: `b53ff80d9e649847995945fa2da163f68a876f46`, with the new process
  stress module and Makefile integration uncommitted at build time.
- Test source SHA-256:
  `15be2a129b07431d39259d0648c7ff1aa133990ec03a86172ee21913f1cdf36e`.
- ch32fun: `618bba58c615ed29dc99e6ea92d869c914b6a8c0`, clean checkout.
- GCC: `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0`; OTP 27, ERTS 15.2.7.
- Options: `CONCURRENCY=1 TIMERS=1 MAX_PROCESSES=2 C_STACK_RESERVE_BYTES=2048`,
  no optional peripherals, default 1,024-byte minimum flash headroom.
- Image: `AtomVM-uiapduino-pro-micro-ch32v006-process-stress-self-test.bin`;
  61,564 bytes, leaving 1,924 flash bytes.
- BIN SHA-256:
  `78198dd712d36c0709ff73cb7e95252f4029f97d5aede003fddb6e7c42405e53`.

Rebuild from the platform directory with
`make CH32FUN=/path/to/ch32fun/ch32fun process-stress-image`. Keep its sibling
`.build-info.txt` with the board output. The terminal was captured for 10 seconds;
the workload's elapsed duration was not independently measured.

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4272/5704 bytes, peak 4568
AtomVM process heap: 45 words, 34 free
AtomVM C stack peak: 652/2048 bytes
ok
```

The final `ok` includes the production stack-guard check. Peak allocator
headroom was 1,136 bytes and measured C-stack headroom was 1,396 bytes.
Host OTP 27 checks also passed with a test-only `report/1` stub; substituting
permanent `system_limit` errors for spawn calls produced `failed` after exactly
20 attempts. This validates the test's retry bound, not hardware scheduling.

A separate OTP 28.5.0.1 build passed AOT, instruction, ABI, and flash checks at
61,572 bytes (1,916 free). Its final BIN was also checked to contain the exact
generated BEAM and ABI-canary bytes. It was not flashed; the board result above
belongs to the OTP 27 image.

## Timer/message stress — 2026-09-07

The new `timer-stress-image` passed on the UIAPduino Pro Micro CH32V006 without
external wiring. It expires 256 receive waits, each followed by a numbered
request/reply with a 200 ms receive deadline. The 25 ms waits total at least
6.4 seconds; the terminal was captured for 20 seconds. This is repeated-use
coverage, not a SysTick-wrap, process-recreation, or allocation-fault test.

Build identity:

- AtomVM base: `01b64ab1d17c36f9d76b2e25f53f8da14dcc54e6`, with the new stress
  module and its Makefile integration uncommitted at build time.
- Test source SHA-256:
  `2236f0c44df418e29268821b16d45d64283b3b1044fd112af42ddc65ceb3f9e4`.
- ch32fun: `618bba58c615ed29dc99e6ea92d869c914b6a8c0`, clean checkout.
- GCC: `riscv64-unknown-elf-gcc (14.2.0+19) 14.2.0`; OTP 27, ERTS 15.2.7.
- Options: `CONCURRENCY=1 TIMERS=1 MAX_PROCESSES=2 C_STACK_RESERVE_BYTES=2048`,
  no optional peripherals, default 1,024-byte minimum flash headroom.
- Image: `AtomVM-uiapduino-pro-micro-ch32v006-timer-stress-self-test.bin`;
  62,160 bytes, leaving 1,328 flash bytes.
- BIN SHA-256:
  `992d44a98a76cb191c75dc00e38b6744f6a38e5032ff52722cf9eb4b0e88dd08`.

Rebuild from the platform directory with
`make CH32FUN=/path/to/ch32fun/ch32fun timer-stress-image`. Its sibling
`.build-info.txt` contains the remaining artifact hashes and compiler flags.
Use the recorded tool versions when comparing sizes; CI uses OTP 28.

Board output:

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4656/5704 bytes, peak 4912
AtomVM process heap: 34 words, 33 free
AtomVM C stack peak: 652/2048 bytes
ok
```

The final `ok` includes the production stack-guard check. Peak allocator
headroom was 792 bytes and measured C-stack headroom was 1,396 bytes.
These margins apply only to this workload and configuration.

The same source also passed on host OTP 27 with a test-only `report/1` stub:
the successful run took 6,657 ms, and an injected unexpected message produced
`failed`. This checks workload behavior, not the RV32E scheduler.

A separate host build with OTP 28.5.0.1 passed AOT, native-instruction, ABI, and
flash checks at 62,164 bytes (1,324 free). That image was not flashed; the board
result above belongs to the OTP 27 image.

## Elixir byte-binary application — 2026-09-08

The fixture-free `BinaryPacket` example constructs a three-byte packet from
runtime function arguments and asserts its exact contents. This exercises the
Elixir-to-BEAM-to-RV32E path for byte-binary construction and matching rather
than adding another synthetic runtime operation.

The image was built from AtomVM `c2c2b15bf86be1a0582b20a903432051f9b82577`
with the example, documentation, and CI integration uncommitted. The Elixir
source was compiled with Elixir 1.19.5 / OTP 28.5.0.1; AOT and firmware were
built with OTP 27 / ERTS 15.2.7, GCC 14.2.0, and clean ch32fun
`618bba58c615ed29dc99e6ea92d869c914b6a8c0`.

- Configuration: `BINARIES=1`, default 1,536-byte C-stack reserve, no optional
  peripherals, and no external wiring.
- Image: `AtomVM-uiapduino-pro-micro-ch32v006-elixir-binary-packet.bin`;
  51,576 bytes, leaving 11,912 flash bytes.
- SHA-256:
  `4304acb894379a88fb364d61c22edaf21941ef2ab26f122868adc72fed4dd23d`.
- Completion condition: `AVM CH32V006 boot` followed by `ok` within a 12-second
  monitor capture; the board produced both lines.

This non-instrumented application result complements the byte-binary and
binary-allocation-failure self-tests recorded below. It does not add fresh
allocator or C-stack measurements and is therefore application evidence, not
by itself promotion evidence.

### Final non-constant-folded rerun — 2026-09-09

The finalized `BinaryPacket` derives the packet's first byte from
`atomvm:platform/0`, preventing the three-byte construction from being
constant-folded while keeping the example fixture-free. The source SHA-256 was
`8775cc54134d4d93197064830cb2b59e5485b82634389abf2f93bc3c4a729548`.
Its Elixir 1.19.5 / OTP 28.5.0.1 BEAM SHA-256 was
`c46c03700c43a53f6858ee6538204ab8b76d755fc63a8168b277ca6b221960a5`.

The final staged tree on AtomVM
`b385a0a2ab7c8641db695a7f62b4cc3729bd53b5`, with GCC 14.2.0 and clean
ch32fun `618bba58c615ed29dc99e6ea92d869c914b6a8c0`, produced 2,984 bytes of
validated native code. The 52,780-byte image left 10,708 flash bytes and had
SHA-256
`eec510447b9e5560c6127b3da1fb9c81078271ff8912d9b15965cee788d40284`.
The physical board again printed `AVM CH32V006 boot` followed by `ok` within
the 12-second acceptance window.

## Byte-binary profile promotion — 2026-09-08

The strengthened `binary-image` constructs and exactly matches fixed-width
byte binaries, checks the boundary value 255 and mismatch behavior, then retains
dynamically allocated byte binaries until process-heap allocation raises
catchable `out_of_memory`. Successful reporting after the exception verifies
controlled recovery. No external wiring was used.

The exact profile was `BINARIES=1`, `CONCURRENCY=0`, `TIMERS=0`, no optional
peripherals, and a 1,536-byte C-stack reserve. Both board runs reported:

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4320/6232 bytes, peak 5248
AtomVM process heap: 44 words, 27 free
AtomVM C stack peak: 948/1536 bytes
ok
```

Peak allocator headroom was 984 bytes and measured C-stack headroom was 588
bytes. The OTP 27 image was 55,424 bytes (8,064 free), with SHA-256
`aebc0a428a8a60f45200b1c50edc6a98b2e001fcbd417f1c3a103173f6172905`.
The OTP 28 image was 55,432 bytes (8,056 free), with SHA-256
`9de2c07500afc4f57816cbe096557637c81e95eba5524c769a26aee9915913a2`.
Both used GCC 14.2.0 and clean ch32fun
`618bba58c615ed29dc99e6ea92d869c914b6a8c0`; the test and negative-validation
changes were uncommitted on AtomVM `b385a0a2ab7c8641db695a7f62b4cc3729bd53b5`.

Host negative tests additionally reject non-byte and variable-sized segments,
binary copying/appending, UTF segments, and sub-binaries under the binary AOT
target. Together with the Elixir packet application above, this evidence
promotes only the bounded configuration in
[ADR 0007](adr/0007-promote-byte-binary-profile.md), not general binary support
or combinations with other capability tiers.

### OTP 27 and OTP 28 requalification — 2026-09-09

The current staged byte-binary workload was rebuilt and rerun after its retained
binary allocation loop and AOT guards were finalized. It passed on the same
board without external wiring:

```text
AVM CH32V006 boot
SysTick time ok
RV32E ABI ok
AtomVM self-test: passed
AtomVM heap: 4712/6232 bytes, peak 5192
AtomVM process heap: 137 words, 6 free
AtomVM C stack peak: 948/1536 bytes
ok
```

The OTP 27 / ERTS 15.2.7 image was 57,092 bytes (6,396 free), with SHA-256
`7ba96279f2afc71f35916d8963113a0a89014a9ed17e8117b77c36532ae69aa8`.
The OTP 28 / ERTS 16.4.0.1 image was 57,100 bytes (6,388 free), with SHA-256
`55418f273cf65c9a27bcded62af75d2f20a3fab8f4c888e1298a4247354c1610`.
Both reported the output above. Peak allocator headroom was 1,040 bytes and
measured C-stack headroom was 588 bytes. Both used GCC 14.2.0 and clean ch32fun
`618bba58c615ed29dc99e6ea92d869c914b6a8c0`; the byte-binary promotion changes
were staged on AtomVM `b385a0a2ab7c8641db695a7f62b4cc3729bd53b5`.

The separate OTP 28 allocator fault-injection image was also strengthened and
rerun. Its expected 64-byte ref-counted-binary allocation failure was catchable,
a second 64-byte allocation succeeded, the self-test passed, and execution
recovered to print `ok`. The 51,668-byte image left 11,820 bytes of flash and
had SHA-256
`400a4e51793b81645b115013c098f9e42915890cb6637f9b3e7b51731af82e61`.
It reported 4,312/6,224 allocator bytes with the same peak, 25 process-heap
words with 17 free, and a 660/1,536-byte C-stack peak.

The complete OTP 28 `qualification-images` matrix was rebuilt successfully
from clean AtomVM commit `a93651654ac9d6347536a9116ad29eeca05a212d`.
All 29 newly generated image build records identify that commit and a clean
AtomVM tree. The byte-binary and allocator-fault image hashes remained the
values recorded above, so the physical-board results apply to those exact
binaries. The matrix covered every platform image profile as well as the
positive and negative host gates; no new build failures were observed.

## Host build measurements — 2026-09-08

Representative self-test image sizes:

| Image | Bytes | Flash remaining |
| --- | ---: | ---: |
| language/runtime | 51,116 | 12,372 |
| arithmetic boundary | 56,480 | 7,008 |
| ADC | 49,744 | 13,744 |
| UART | 51,276 | 12,212 |
| SPI | 51,528 | 11,960 |
| PWM | 52,184 | 11,304 |
| I2C | 52,888 | 10,600 |
| GPIO IRQ | 53,052 | 10,436 |
| byte binaries | 50,664 | 12,824 |
| bounded I/O binary | 49,828 | 13,660 |
| concurrency | 52,412 | 11,076 |
| concurrency memory pressure | 52,416 | 11,072 |
| spawn allocation OOM | 49,400 | 14,088 |
| repeated spawn OOM/recovery | 51,940 | 11,548 |
| message allocation OOM (sustained) | 52,640 | 10,848 |
| receive timeouts | 51,808 | 11,680 |
| combined timer/GPIO application | 52,836 | 10,652 |
| timer memory pressure | 51,808 | 11,680 |
| timer stress | 52,956 | 10,532 |
| timer rollover | 52,652 | 10,836 |
| production timer soak | 51,704 | 11,784 |
| process cleanup stress | 52,364 | 11,124 |
| timer allocation OOM | 52,144 | 11,344 |
| binary allocation OOM | 50,996 | 12,492 |

These numbers include one acceptance application and will change with code or
toolchain revisions. The dedicated small-integer arithmetic handlers recovered
about 9.3 KiB across the matrix; GPIO IRQ is now the largest listed Erlang image
apart from the intentionally broader arithmetic-boundary workload and remains
10,436 bytes below the flash limit. The boundary image itself leaves 7,008
bytes. All 29 Erlang qualification images passed the opcode,
native-instruction, variant, ELF ABI, and flash gates.

The separately built Elixir external-send images use the same runtime and leave
11,028, 10,424, and 12,216 bytes respectively. These host results renew build
evidence only. Existing electrical-test gaps and workload-specific SRAM/stack
limits remain unchanged.

## Board observations

Hardware baseline recorded on 2026-09-05 with a UIAPduino Pro Micro CH32V006
and the language self-test image (`60,372` bytes): SysTick and RV32E ABI checks
passed, the AtomVM self-test passed, and the image finished with `ok`. The
runtime reported `4,480/6,328` bytes of heap in use (peak `4,656`) and a C-stack
peak of `1,220/1,432` bytes, leaving `212` bytes of measured stack margin.
Keep the stack canary enabled and treat this margin as a constraint for larger
applications.

The two-process concurrency image (`61,576` bytes) was also run on the board:
spawn/send/receive and the two-process limit check passed with `ok`. It reported
`4,160/6,320` bytes of heap in use (peak `4,768`), `20` process-heap words with
one free, and a C-stack peak of `656/1,432` bytes.

The same concurrency workload with a 2,048-byte C-stack reserve (`61,580`
bytes) also passed on hardware. It reported `4,160/5,704` bytes of heap in use
(peak `4,768`), `20` process-heap words with one free, and a C-stack peak of
`656/2,048` bytes.

The spawn-allocation-failure image was rerun with the 2,048-byte C-stack
reserve on 2026-09-06 (`58,580` bytes). The injected `context_new()` failure
was catchable, the diagnostic included its source line, the AtomVM self-test
passed, and the image finished with `ok`. It reported `4,152/5,696` bytes of
heap in use (peak `4,152`), `8` process-heap words with six free, and a C-stack
peak of `656/2,048` bytes.

The sustained three-cycle message-allocation-failure image (`61,836` bytes)
passed on hardware on 2026-09-06. Each injected send failure was followed by a
successful recovery send; the AtomVM self-test passed and the image finished
with `ok`. It reported `4,664/5,696` bytes of heap in use (peak `4,880`), `34`
process-heap words with 32 free, and a C-stack peak of `656/2,048` bytes.

The timer memory-pressure image (`61,012` bytes) passed on hardware with the
timer workload and self-test completing with `ok`. It reported `4,088/5,704`
bytes of heap in use (peak `4,656`), `14` process-heap words with four free,
and a C-stack peak of `652/2,048` bytes.

The ADC smoke-test image (`59,048` bytes) passed on hardware with channel 0
returning an in-range sample and a final `ok`. It reported `4,032/6,312` bytes
of heap in use (peak `4,032`), `8` process-heap words with seven free, and a
C-stack peak of `660/1,432` bytes. No known voltage was applied, so this does
not yet qualify ADC accuracy or pin calibration.

The PWM smoke-test image (`61,268` bytes) passed on hardware with the argument
guards and TIM1/PC3 path completing with `ok`. It reported `4,096/6,320` bytes
of heap in use (peak `4,096`), `8` process-heap words with seven free, and a
C-stack peak of `660/1,432` bytes. Electrical frequency and duty-cycle
measurement remains outstanding.

The binary-allocation-failure image (`60,220` bytes) passed on hardware with
the expected allocation diagnostic, the AtomVM self-test passing, and a final
`ok`. It reported `4,120/6,320` bytes of heap in use (peak `4,120`), `8`
process-heap words with no free words, and a C-stack peak of `656/1,432` bytes.

The byte-binary construction/matching image (`59,896` bytes) passed on hardware
with the exact-match workload and self-test completing with `ok`. It reported
`4,048/6,328` bytes of heap in use (peak `4,048`), `20` process-heap words with
seven free, and a C-stack peak of `672/1,432` bytes. Sub-binaries, UTF
segments, floats, and arbitrary binary copying remain unsupported.

The normal timer/receive-timeout image (`61,012` bytes) passed on hardware with
the timeout workload and self-test completing with `ok`. It reported
`4,088/6,320` bytes of heap in use (peak `4,656`), `14` process-heap words with
four free, and a C-stack peak of `652/1,432` bytes.

The one-cycle timer-allocation-failure image (`61,380` bytes) passed on hardware
on 2026-09-06 with the 2,048-byte C-stack reserve. A child hit an injected
mailbox allocation failure while the parent had an active receive timeout; the
timeout still expired and the child's following message was received. The image
finished with `ok` and reported `4,120/5,696` bytes of heap in use (peak
`4,664`), `11` process-heap words with five free, and a C-stack peak of
`652/2,048` bytes. Keep the timer stress image at one cycle until the runtime
or image size is reduced further.
