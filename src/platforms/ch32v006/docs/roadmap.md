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
| two-process memory pressure | build-qualified experiment | hardware run with the 2,048-byte C-stack reserve |
| spawn allocation failure | build-qualified experiment | hardware run with stack guard and heap readings |
| receive timeouts | build-qualified experiment | hardware timing and long-run test |
| timer memory pressure | build-qualified experiment | hardware run with the 2,048-byte C-stack reserve |
| byte-integer binary construction/exact matching | build-qualified experiment | hardware construction/matching test |
| binary allocation failure | build-qualified experiment | run the binary-OOM image on hardware and confirm stack guard/headroom |
| GPIO edge polling | build-qualified driver | physical rising/falling-edge tests |
| UART1 | build-qualified driver | physical PD5/PD6 loopback and timeout test |
| ADC | build-qualified driver | known-voltage measurements on PA2/A0 |
| I2C1 | build-qualified driver | device read/write and bus-recovery tests |
| SPI1 | build-qualified driver | PC6/PC7 loopback and device test |
| TIM1 PWM | build-qualified driver | frequency/duty measurements on PC3/PC4 |

“Build-qualified” means the final firmware passes AOT, instruction, ABI, and
size validation. It does not mean the electrical behavior has been verified.

Representative self-test image sizes measured on 2026-09-05:

| Image | Bytes | Flash remaining |
| --- | ---: | ---: |
| ADC | 59,048 | 4,440 |
| UART | 60,372 | 3,116 |
| SPI | 60,816 | 2,672 |
| PWM | 57,844 | 5,644 |
| I2C | 62,244 | 1,244 |
| GPIO IRQ | 59,760 | 3,728 |
| byte binaries | 59,896 | 3,592 |
| concurrency | 61,576 | 1,912 |
| concurrency memory pressure | 61,580 | 1,908 |
| concurrency allocation OOM | 58,556 | 4,932 |
| receive timeouts | 61,012 | 2,476 |
| timer memory pressure | 61,012 | 2,476 |
| binary allocation OOM | 60,220 | 3,268 |

These numbers include one acceptance application and will change with code or
toolchain revisions. The timer image has a healthier margin now, but remains
sensitive to growth because concurrency and timers add substantial runtime code.
The I2C image is currently the tightest peripheral image after its argument
guards were added.

## Near-term work

1. Hardware-qualify concurrency, spawn allocation failure, and timers,
   including allocator and stack measurements. Keep the maximum at two
   processes until evidence supports more.
2. Hardware-qualify each driver independently, starting with UART loopback and
   known-voltage ADC, then I2C/SPI devices, PWM, and GPIO edges.
3. Run the binary-allocation OOM image on the board and record the allocator
   and C-stack readings. Keep sub-binaries, UTF segments, floats, and arbitrary
   binary copying as AOT errors.
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
