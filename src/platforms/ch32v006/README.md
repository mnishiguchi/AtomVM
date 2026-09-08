# AtomVM on UIAPduino Pro Micro CH32V006

This port runs one RV32E-AOT-compiled AtomVM module on the UIAPduino Pro Micro
CH32V006 V1.1 Beta. The board has 63,488 usable flash bytes and 8 KiB SRAM, so
this is a deliberately constrained AtomVM tier, not ESP32 feature parity.

- [Getting started](docs/getting-started.md): build, flash, monitor, and
  create an Elixir project
- [Elixir examples](../../../examples/elixir/ch32v006/README.md): LED blink and
  button input
- [Documentation](docs/README.md): design, roadmap, and architecture decisions

## Requirements

- Erlang/OTP 28 and GNU Make
- `riscv64-unknown-elf-gcc`, binutils, and newlib headers
- [ch32fun](https://github.com/cnlohr/ch32fun) at
  `618bba58c615ed29dc99e6ea92d869c914b6a8c0`
- a UIAP programmer (`1209:b806`) accessible by the current user

`CH32FUN` must point to the inner directory containing `ch32fun.mk`.
The build keeps an OTP-specific host-tool stamp and recompiles its Erlang AOT
tools when the active OTP release changes.

## Build

From this directory, build the bundled blink firmware:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun clean image
```

The flashable file is
`build/images/AtomVM-uiapduino-pro-micro-ch32v006.bin`. The image target also
checks the flash limit, reserves at least 1,024 bytes of flash headroom by
default, and validates the RV32E ELF ABI. It produces a checksum, HEX, ELF, and
`.build-info.txt` record for tracing the image used in a board test.
Override the margin only for an explicit experiment with `MIN_FLASH_HEADROOM`.

The staging directory is fixed at `build/` because the assembly embeds files
from it. Use `IMAGE_DIR=/path/to/images` for a different artifact destination;
overriding `BUILD_DIR` is rejected.

Embed a different Erlang source or an already compiled Elixir/Erlang BEAM:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun \
  START_SOURCE=/path/to/app.erl image

make CH32FUN=/path/to/ch32fun/ch32fun \
  START_BEAM_INPUT=/path/to/Elixir.App.beam image
```

The startup module must export `start/0`. CH32V006 has no separate AtomVM and
application partitions: every BIN contains the runtime and one application,
so changing the application rebuilds and reflashes the complete firmware.

Build the normal, language, reduced-heap, controlled initial-allocation OOM,
process-heap OOM, and GPIO acceptance images with:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun acceptance-images
```

## Optional capability images

The stable image stays deliberately small. Additional runtime and peripheral
features are selected at build time and are not implied by a default build:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun concurrency-image
make CH32FUN=/path/to/ch32fun/ch32fun concurrency-memory-image
make CH32FUN=/path/to/ch32fun/ch32fun concurrency-oom-image
make CH32FUN=/path/to/ch32fun/ch32fun concurrency-send-oom-image
make CH32FUN=/path/to/ch32fun/ch32fun arithmetic-boundary-image
make CH32FUN=/path/to/ch32fun/ch32fun external-send-image
make CH32FUN=/path/to/ch32fun/ch32fun external-send-lifecycle-image
make CH32FUN=/path/to/ch32fun/ch32fun external-send-badarg-image
make CH32FUN=/path/to/ch32fun/ch32fun combined-image
make CH32FUN=/path/to/ch32fun/ch32fun timer-image
make CH32FUN=/path/to/ch32fun/ch32fun timer-memory-image
make CH32FUN=/path/to/ch32fun/ch32fun timer-stress-image
make CH32FUN=/path/to/ch32fun/ch32fun timer-wrap-image
make CH32FUN=/path/to/ch32fun/ch32fun timer-production-soak-image
make CH32FUN=/path/to/ch32fun/ch32fun process-stress-image
make CH32FUN=/path/to/ch32fun/ch32fun process-oom-stress-image
make CH32FUN=/path/to/ch32fun/ch32fun timer-oom-image
make CH32FUN=/path/to/ch32fun/ch32fun binary-image
make CH32FUN=/path/to/ch32fun/ch32fun binary-oom-image
make CH32FUN=/path/to/ch32fun/ch32fun io-binary-image
make CH32FUN=/path/to/ch32fun/ch32fun peripheral-images
```

`timer-stress-image` repeats 256 timeout/message cycles with a 2,048-byte
C-stack reserve (at least 6.4 seconds of scheduled waits). Each reply carries
its cycle number. This checks repeated timer and mailbox use; it does not
exercise SysTick counter wraps or inject allocation failures.

`combined-image` is a fixture-free application check: two processes exchange a
completion message while receive timeouts drive eight onboard LED transitions.
It combines GPIO with the concurrency and timer tiers and uses the 2,048-byte
C-stack reserve.

`timer-wrap-image` is a test-only accelerated rollover check. It places the
32-bit SysTick counter 30 ms before zero, schedules a 50 ms receive timeout
across the wrap, verifies monotonic time advanced, and then exercises another
timed message exchange. The counter manipulation and its two helper NIFs are
absent from normal firmware.

`timer-production-soak-image` uses the production SysTick tracking interval. A
1,432,000 ms receive timeout crosses two natural 32-bit counter wraps without
repositioning the counter, verifies four tracking interrupts and monotonic
elapsed time, then delivers a child-to-parent completion message. Allow 25
minutes when monitoring it; no external wiring is needed.

`process-stress-image` creates 256 short-lived children sequentially, verifying
each numbered reply under the two-process limit and a 2,048-byte C-stack reserve.
It makes at most 20 spawn attempts, yielding after `system_limit`, then
fails if the previous child's slot cannot be reused. Other spawn errors fail
immediately. This checks repeated process/context reclamation without fixtures.

`process-oom-stress-image` repeats 64 injected `context_new()` failures. Every
failed spawn must raise catchable `out_of_memory`; it is followed by a successful
child spawn, message, termination, and process-slot reuse. It uses the
2,048-byte C-stack reserve and emits one expected allocation diagnostic per
cycle, so a SWIO run takes substantially longer than the Erlang workload alone.

The three `external-send-*` targets require `elixirc`. They check the external
`erlang:send/2` NIF used by Elixir: allocation failure and recovery, terminated
local PIDs, and invalid recipients. Each build verifies external calls in the
BEAM and rejects a send opcode, then uses the concurrency tier with a 2,048-byte
stack reserve. Separate images keep the tests within the flash-headroom policy.
CI builds them alongside the Elixir examples; `qualification-images` remains
Erlang-only. No wiring is needed; require `AtomVM self-test: passed` followed by
`ok` within a 10-second monitor capture for each image.

These targets pass AOT, native-instruction, RV32E ABI, and flash-size checks.
The exact two-process timer profile described below is hardware-qualified;
binary and peripheral capabilities remain experimental. `concurrency-oom-image`
arms a test-only allocator fault immediately
before `spawn/3` and expects a catchable `error:out_of_memory` when
`context_new()` cannot allocate the child. `concurrency-send-oom-image` keeps
two processes alive, repeats the injected mailbox allocation failure three
times, expects a catchable `error:out_of_memory`, and verifies that the next
message is delivered after each recovery. `timer-oom-image` injects the same
failure from a child while its parent has an active receive timeout; the
timeout and recovery message must survive. It remains a one-cycle stress image
because a second cycle exceeds the flash-headroom policy.
`binary-oom-image` arms a test-only allocator fault immediately before a
64-byte ref-counted binary allocation and must report `error:out_of_memory`
without crossing the stack guard. Their Erlang acceptance sources live under
`tests/`. See the
[roadmap](docs/roadmap.md) for status and measured image sizes.
Host-side AOT validators and negative-test helpers live under `tools/`.

`io-binary-image` verifies the bounded 64-byte heap-binary representation used
for I2C and SPI results without external wiring. It checks the size and every
byte after the value crosses the NIF/BEAM boundary. This target does not qualify
an electrical bus transfer.

`concurrency-memory-image` uses the 2,048-byte C-stack reserve used by the
default memory-pressure acceptance image, leaving less SRAM for process heaps.
`timer-memory-image` applies the same reserve to the timer tier. The spawn,
message, and timer allocation-failure images also use this reserve.

## Flash and monitor

```sh
make CH32FUN=/path/to/ch32fun/ch32fun \
  MINICHLINK=/path/to/ch32fun/minichlink \
  FLASH_IMAGE=build/images/AtomVM-uiapduino-pro-micro-ch32v006.bin \
  flash-uiap

make CH32FUN=/path/to/ch32fun/ch32fun \
  MINICHLINK=/path/to/ch32fun/minichlink monitor-uiap
```

The console is carried over the programmer's HID/SWIO interface, not a serial
TTY, so use minichlink's terminal rather than `tio`. To recover an unavailable
debug connection, power-cycle only the target rail:

```sh
minichlink -c 0x1209b806 -C funprog -t
minichlink -c 0x1209b806 -C funprog -3
```

Keep the `-c 0x1209b806 -C funprog` option order shown above.

## GPIO

Pins use ch32fun numbering: PA0 is `0`, PB0 is `16`, PC0 is `32`, and PD0 is
`48`. The onboard orange LED is PC3 (`35`).

Supported calls are:

- `gpio:init/1` and `gpio:deinit/1`
- `gpio:set_pin_mode/2`: `input`, `output`, or `output_od`
- `gpio:set_pin_pull/2`: `up`, `down`, or `floating`
- `gpio:digital_write/2`: `low`, `high`, `0`, or `1`
- `gpio:digital_read/1`
- `atomvm:platform/0`, which returns `ch32v006`
- `ch32v006:delay_ms/1`

`ch32v006:delay_ms/1` blocks the entire one-thread runtime. It is suitable for
bring-up examples, but it is not equivalent to `Process.sleep/1`.

PC0 (`32`) controls programmer reset and is always rejected. PD1 (`49`) is the
only SWIO programming/debug pin and is also rejected by default. An application
that knowingly gives up programming and console access may opt in at build time
with `ALLOW_SWIO_PIN=1`.

## Supported runtime profiles

The default profile supports one embedded module and startup process, local
calls, tail recursion, allocation and GC, atoms, 28-bit signed integers, lists,
tuples, comparisons, pattern matching, `try/catch`, direct platform NIFs, and
the `+`, `-`, `*`, `div`, `rem`, and `length` BIFs. Opaque binary literals are
also loadable because Elixir stores module metadata in one. Unresolved external
calls raise `undef`, and invalid GPIO arguments raise catchable `badarg` errors.
Arithmetic accepts only 28-bit signed integers. A result outside that range
raises catchable `overflow`; a non-integer operand or zero divisor raises
`badarith`. `arithmetic-boundary-image` verifies these cases without relying on
compile-time constants.

In the default tier, additional processes, send/receive, funs, floats, binary
construction or matching, maps, large integers, dynamic apply, the interpreter,
dynamic module or AVM archive
loading, ports, and SMP are not supported. Missing native helpers, BIFs, and
unsupported literal types are rejected during AOT generation. Each generated
image is also decoded to reject x16-x31, hardware divide/remainder,
floating-point, and other instructions outside `rv32ec_zmmul`.

The default stable profile includes polled GPIO and the blocking delay. A
second stable profile is available with this exact opt-in configuration:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun \
  CONCURRENCY=1 TIMERS=1 MAX_PROCESSES=2 \
  C_STACK_RESERVE_BYTES=2048 START_SOURCE=/path/to/app.erl image
```

It adds the startup process plus one child, same-module `spawn/3`, local-PID
`send/2`, send/receive opcodes, selective receive, and receive timeouts.
Messages may contain atoms, 28-bit integers, local PIDs, lists, and tuples. It
does not support linked spawning, registered names, aliases, distributed PIDs,
ports, funs, dynamic modules, or process timer APIs. Synchronous platform NIFs
block both processes while they access hardware. See
[ADR 0006](docs/adr/0006-promote-two-process-timer-profile.md) for the bounded
contract.

Experiments add byte-sized binary construction/matching, GPIO edge polling,
UART, ADC, I2C, SPI, and PWM. The peripheral APIs are small direct NIFs, not
the port-based APIs used by larger AtomVM platforms.

Experimental driver pinout and acceptance wiring:

| Driver | Pins | Acceptance setup |
| --- | --- | --- |
| GPIO IRQ | PD3 | apply a rising edge to PD3 |
| UART1 | PD5 TX, PD6 RX | connect PD5 to PD6 |
| ADC | PA2 (`A0`) through PD4 (`A7`) | channel 0 test reads PA2 |
| I2C1 | PC1 SDA, PC2 SCL | attach a 7-bit device and pull-ups |
| SPI1 | PC5 SCK, PC6 MOSI, PC7 MISO | connect PC6 to PC7 |
| TIM1 PWM | PC3 CH3, PC4 CH4 | observe either PWM output |

The experimental calls are:

- `gpio:set_pin_interrupt/2`, `gpio:interrupt_pending/1`, and
  `gpio:clear_pin_interrupt/1`
- `uart:init/1`, `uart:write/1`, and nonblocking `uart:read/0`
- `adc:read/1` for channels 0 through 7
- `i2c:init/1`, `i2c:probe/1`, `i2c:write/2`, and `i2c:read/2`
- `spi:init/2`, `spi:transfer_byte/1`, and `spi:transfer/1`; SPI clocks must be
  between 187,500 and 24,000,000 Hz at the default 48 MHz system clock
- `pwm:init/1` and `pwm:set_duty/2`, where duty is 0 through 1000

Call each peripheral's `init` function before using its other functions. Calls
made before initialization return `error` (or `badarg` for invalid arguments).

The I2C, SPI, and UART byte APIs accept at most 64 bytes per call. Driver calls
are synchronous and block the single scheduler thread while accessing hardware;
peripheral polling fails after a 10 ms elapsed-time deadline.
I2C and SPI result buffers stay on the process heap even at 64 bytes, avoiding
separate ref-counted allocations on this constrained target.
Select one or more drivers with `PERIPHERALS="uart adc"`. Select byte binary
construction/matching with `BINARIES=1`; timers require `CONCURRENCY=1
TIMERS=1`. The binary and concurrency experiments cannot yet be combined.

The allocator reserves 1,536 bytes for the C stack, protects that boundary
with a production canary, and accepts an application-specific override:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun \
  C_STACK_RESERVE_BYTES=1664 image
```

Increasing the reserve reduces allocator space by the same amount. Qualify the
exact application on real hardware before adopting a different value. The value
must be an 8-byte multiple between 16 and 8,184 bytes. The build rejects a
value that would otherwise be silently rounded or place the guard outside SRAM.

Run host-side boundary and instruction checks with:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun validation-tests
```
