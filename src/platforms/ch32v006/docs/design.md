# CH32V006 platform design

This document describes the current architecture of the CH32V006 AtomVM port.
For build, flash, GPIO, and support details, see [README.md](../README.md). For
an end-to-end Elixir example, see [getting-started.md](getting-started.md).
The durable decision record is in [ADRs](adr/README.md).

## Hardware constraints

The initial target is the UIAPduino Pro Micro CH32V006 V1.1 Beta.

| Item | Constraint |
| --- | --- |
| MCU | CH32V006 |
| ISA | `rv32ec_zmmul` |
| ABI | `ilp32e` |
| Usable flash | 63,488 bytes |
| SRAM | 8 KiB |
| Onboard LED | PC3 |
| Programmer-sensitive pin | PC0 |
| SWIO pin | PD1 |

The onboard programmer enumerates as USB HID `1209:b806` and is used through
ch32fun's minichlink support.

PC0 is rejected by every GPIO NIF because reconfiguring it can interfere with
the onboard programmer. PD1 is the only SWIO path and is rejected by default;
`ALLOW_SWIO_PIN=1` is an explicit opt-in that can disconnect programming and
the console.

## Why AOT is required

The regular AtomVM interpreter cannot fit the target flash budget. Early sizing
probes placed `scheduler_entry_point` alone at 177,604 bytes, before platform
startup code and an application were included.

The port therefore uses a native-only runtime:

- applications are precompiled with the `riscv32e+minimal` AOT target;
- the platform is built without the BEAM interpreter;
- one precompiled startup module is embedded directly in firmware; and
- only the native-interface functionality required by the advertised support
  tier is linked.

This is intentionally a constrained AtomVM target rather than a smaller copy
of the ESP32 runtime.

## RV32E AOT and ILP32E ABI

The `riscv32e` target shares the existing RISC-V assembler and backend while
using the RV32E register and ABI limits:

- a0-a5 are argument registers;
- t0-t2 are the available temporary registers;
- excess argument words begin at `0(sp)`;
- a 64-bit argument may split between a5 and the first stack word; and
- outgoing RV32E stack areas use the ILP32E 4-byte stack alignment.

Tail primitive calls use the direct tail-call path when all prepared arguments
fit in registers. If outgoing stack arguments are required, the backend emits
a regular call followed by a return so that the generated frame can restore
the stack correctly.

The platform self-test includes a generated ABI canary that calls a C function
with more than six ABI words, including 64-bit arguments. This validates the
generated calling convention against the compiler used for the physical
CH32V006 firmware.

The `minimal` native-code variant records the reduced native-interface ABI in
the image header. A regular RV32E image is therefore incompatible with this
runtime instead of being allowed to call absent helpers.

The current RV32E target is `rv32ec_zmmul`, so the backend does not advertise
hardware `div` or `rem` generation. The generic JIT therefore falls back to the
linked BIF implementations, while native-code validation rejects any accidental
hardware divide or remainder instruction.

## Constrained runtime boundary

The current support tier is deliberately narrow. It includes:

- one embedded startup module and one scheduled process;
- local calls and tail recursion;
- allocation and garbage collection;
- atoms, 28-bit signed integers, lists, tuples, and opaque binary literals
  (needed by Elixir's generated `__info__/1` metadata);
- comparisons and pattern matching;
- `try/catch` and the required exception-unwind paths;
- `+`, `-`, `*`, `div`, `rem`, and `length`; and
- the documented direct platform NIFs.

Unresolved external calls raise `undef`. Invalid platform-NIF arguments raise
catchable `badarg` errors.

The target does not provide:

- the BEAM interpreter;
- the complete AtomVM BIF/NIF or instruction surface;
- processes, messages, funs, floats, binary construction and matching, maps,
  large-integer literals, and dynamic apply;
- qualified behavior for arithmetic results outside the 28-bit small-integer
  range;
- dynamic module loading;
- AVM archive loading;
- ports; or
- SMP.

Adding another operation is therefore a platform-support decision, not merely
a registry change. It must fit the flash and SRAM budgets and be covered by
host and physical-board validation.

## Firmware model

A CH32V006 image is complete application firmware:

```text
constrained AtomVM runtime
+
one RV32E-precompiled startup module
```

There is no independent application partition. Updating the application
relinks and reflashes the complete firmware.

The build accepts either an Erlang source through `START_SOURCE` or an already
compiled BEAM through `START_BEAM_INPUT`. Literal-bearing BEAM input is
packaged with uncompressed `LitU` data so the constrained runtime does not need
zlib.

The standard image workflow produces BIN, checksum, HEX, and debug ELF
artifacts. Versioned release images contain the runtime and application
together and are directly flashable with minichlink.

## SRAM strategy

The 8 KiB SRAM budget must cover static data, VM state, the process heap/stack,
the native allocator, and the C stack.

The platform therefore uses:

- a 1,432-byte C-stack reserve;
- best-fit allocation;
- free-block coalescing;
- in-place `realloc` shrinking and growth where possible;
- immutable NIF descriptors stored in flash; and
- a 20-entry inline term-comparison stack.

Every build places a canary at the allocator/C-stack boundary and aborts with a
visible failure if it is crossed. Acceptance builds also paint the reserved
stack and report its high-water mark. The probe starts before boot output and
the ABI canary, so the measurement includes those paths and the AtomVM workload.

Memory constants should be changed only from measured physical-board results.
Reducing the C-stack reserve gives the allocator more space but risks native
stack exhaustion; increasing it reduces the largest contiguous region
available to the VM and garbage collector.

## Time and scheduling

ch32fun exposes a 32-bit SysTick value on this target. A periodic SysTick
interrupt maintains a software extension independently of application reads,
so monotonic milliseconds remain correct across counter wraps.

`ch32v006:delay_ms/1` is intentionally a blocking bring-up helper. While it
runs, the single scheduler thread cannot execute another AtomVM process. A
future multi-process support tier should use scheduler-aware timer behavior
instead of extending this helper.

## Validation strategy

The port is qualified at several layers:

- focused RV32E backend tests;
- negative AOT tests for every excluded BEAM value/execution family;
- decoding of generated machine code to reject x16-x31, hardware `div`/`rem`,
  floating-point, and other instructions outside `rv32ec_zmmul`;
- regression tests for the regular RV32 and RV64 backends;
- generated ILP32E ABI canary code;
- flash-size and ELF ABI checks;
- a language/runtime acceptance image;
- a reduced-heap language image, controlled initial-process allocation failure,
  and catchable process-heap exhaustion;
- a GPIO acceptance image;
- a normal blink image;
- generic Unix build checks; and
- physical-board flash, boot, memory, and sustained-run observations.

The language/runtime and GPIO workloads remain separate because combining them
would exceed the 63,488-byte flash budget.

Physical-board validation is the authority for stack headroom, allocator
behavior, GPIO electrical behavior, and sustained execution. Changes to the
RV32E ABI path, stack reservation, allocator, native-interface layout, or
upstream precompiler/runtime interfaces require renewed hardware
qualification.

## Peripheral qualification

Hello World, GPIO output, and polled GPIO input are qualified today. GPIO
interrupts, timers, PWM, ADC, UART, I2C, SPI, and a combined application remain
future work. Each capability should be selected explicitly at compile time so
unused drivers do not consume the fixed flash and SRAM budgets.

## Design boundary

The goal is a reproducible and useful AtomVM platform for a severely
resource-constrained RV32E MCU. Success means that the documented constrained
surface builds, fits, flashes, boots, and behaves correctly.

It does not mean feature or resource parity with larger AtomVM platforms.
