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

## Build

From this directory, build the bundled blink firmware:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun clean image
```

The flashable file is
`build/images/AtomVM-uiapduino-pro-micro-ch32v006.bin`. The image target also
checks the flash limit and RV32E ELF ABI and produces a checksum, HEX, and ELF.

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

## Experimental capability images

The stable image stays deliberately small. Additional runtime and peripheral
features are selected at build time and are not implied by a default build:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun concurrency-image
make CH32FUN=/path/to/ch32fun/ch32fun timer-image
make CH32FUN=/path/to/ch32fun/ch32fun binary-image
make CH32FUN=/path/to/ch32fun/ch32fun peripheral-images
```

These targets pass AOT, native-instruction, RV32E ABI, and flash-size checks.
They still require physical-board qualification before promotion to the stable
tier. See the [roadmap](docs/roadmap.md) for status and measured image sizes.

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

## Supported runtime tier

The tested tier supports one embedded module and startup process, local calls,
tail recursion, allocation and GC, atoms, 28-bit signed integers, lists,
tuples, comparisons, pattern matching, `try/catch`, direct platform NIFs, and
the `+`, `-`, `*`, `div`, `rem`, and `length` BIFs. Opaque binary literals are
also loadable because Elixir stores module metadata in one. Unresolved external
calls raise `undef`, and invalid GPIO arguments raise catchable `badarg` errors.

Processes, send/receive, funs, floats, binary construction or matching, maps,
large integers, dynamic apply, the interpreter, dynamic module or AVM archive
loading, ports, and SMP are not supported. Missing native helpers, BIFs, and
unsupported literal types are rejected during AOT generation. Each generated
image is also decoded to reject x16-x31, hardware divide/remainder,
floating-point, and other instructions outside `rv32ec_zmmul`.

Only polled GPIO and the blocking delay belong to the stable platform tier.
Opt-in experiments add two same-module processes, receive timeouts, byte-sized
binary construction/matching, GPIO edge polling, UART, ADC, I2C, SPI, and PWM.
The peripheral APIs are small direct NIFs, not the port-based APIs used by
larger AtomVM platforms.

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

The I2C, SPI, and UART byte APIs accept at most 64 bytes per call. Driver calls
are synchronous and block the single scheduler thread while accessing hardware;
peripheral polling fails after a 10 ms elapsed-time deadline.
Select one or more drivers with `PERIPHERALS="uart adc"`. Select byte binary
construction/matching with `BINARIES=1`; timers require `CONCURRENCY=1
TIMERS=1`. The binary and concurrency experiments cannot yet be combined.

The allocator reserves 1,432 bytes for the C stack, protects that boundary
with a production canary, and accepts an experimental override:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun \
  C_STACK_RESERVE_BYTES=1536 acceptance-images
```

Increasing the reserve reduces allocator space by the same amount. Use the
acceptance images on real hardware before adopting a different value.

Run host-side boundary and instruction checks with:

```sh
make CH32FUN=/path/to/ch32fun/ch32fun validation-tests
```
