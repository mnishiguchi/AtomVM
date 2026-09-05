# CH32V006 platform roadmap

The default CH32V006 image is a stable constrained AOT-only AtomVM tier. New
capabilities advance independently so experiments cannot weaken that contract
or silently consume the board's 63,488-byte flash and 8 KiB SRAM budgets.

## Qualification rules

A capability moves to the stable tier only after it has:

1. deterministic AOT rejection for unsupported operations;
2. host, RV32E ABI, native-instruction, and flash-size checks;
3. a focused physical-board acceptance test; and
4. measured heap and C-stack headroom under memory pressure.

If a capability cannot meet those gates, it remains optional or unsupported.

## Current status

| Capability | Status | Next gate |
| --- | --- | --- |
| one module/process, language subset, polled GPIO | stable | preserve regression coverage |
| two same-module processes, spawn/send/receive | build-qualified experiment | rerun final image on hardware and measure memory |
| receive timeouts | build-qualified experiment | hardware timing and long-run test |
| byte-integer binary construction/exact matching | build-qualified experiment | hardware and OOM tests |
| GPIO edge polling | build-qualified driver | physical rising/falling-edge tests |
| UART1 | build-qualified driver | PD5/PD6 loopback and error-path tests |
| ADC | build-qualified driver | known-voltage measurements on PA2/A0 |
| I2C1 | build-qualified driver | device read/write and bus-recovery tests |
| SPI1 | build-qualified driver | PC6/PC7 loopback and device test |
| TIM1 PWM | build-qualified driver | frequency/duty measurements on PC3/PC4 |

“Build-qualified” means the final firmware passes AOT, instruction, ABI, and
size validation. It does not mean the electrical behavior has been verified.

Representative self-test image sizes measured on 2026-09-05:

| Image | Bytes | Flash remaining |
| --- | ---: | ---: |
| ADC | 57,244 | 6,244 |
| UART | 57,852 | 5,636 |
| SPI | 59,844 | 3,644 |
| PWM | 57,844 | 5,644 |
| I2C | 59,708 | 3,780 |
| GPIO IRQ | 59,760 | 3,728 |
| byte binaries | 59,896 | 3,592 |
| concurrency | 61,576 | 1,912 |
| receive timeouts | 61,012 | 2,476 |

These numbers include one acceptance application and will change with code or
toolchain revisions. The timer image has a healthier margin now, but remains
sensitive to growth because concurrency and timers add substantial runtime code.

## Near-term work

1. Hardware-qualify concurrency and timers, including allocator and stack
   measurements. Keep the maximum at two processes until evidence supports more.
2. Hardware-qualify each driver independently, starting with UART loopback and
   known-voltage ADC, then I2C/SPI devices, PWM, and GPIO edges.
3. Add controlled binary-allocation failure coverage. Keep sub-binaries, UTF
   segments, floats, and arbitrary binary copying as AOT errors.
4. Use the first real peripheral application to decide which runtime and driver
   combination deserves optimization. Do not enable all experiments by default.
5. Attempt a small combined application only after its required tiers fit with
   credible flash, heap, and C-stack margins.

## Later investigations

- Embed and resolve multiple precompiled AOT modules without a filesystem or
  dynamic loader.
- Align direct peripheral NIFs with existing AtomVM APIs where the port/resource
  cost is affordable.
- Investigate maps, floats, broader binaries, or additional standard-library
  functions only for a demonstrated application requirement.

The BEAM interpreter, standard AVM archive loading, dynamic module loading,
ports, and SMP are not current goals.

## Upstream shape

Keep reviewable changes separated into RV32E/ILP32E backend support, constrained
runtime support, CH32V006 MCU support, UIAPduino board configuration, and
examples/tests/CI. Rebase onto the intended upstream branch when preparing each
submission rather than continuously moving the experimental branch.
