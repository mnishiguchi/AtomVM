# CH32V006 platform roadmap

The default CH32V006 image is a stable constrained AOT-only AtomVM tier. New
capabilities advance independently so experiments cannot weaken that contract
or silently consume the board's 63,488-byte flash and 8 KiB SRAM budgets.

## Qualification rules

A capability moves to the stable tier only after it has:

1. deterministic AOT rejection for unsupported operations;
2. host, RV32E ABI, native-instruction, flash-size, and headroom checks;
3. a focused physical-board acceptance test; and
4. measured heap and C-stack headroom under memory pressure.

If a capability cannot meet those gates, it remains optional or unsupported.

## Current status

| Capability | Status | Next gate |
| --- | --- | --- |
| one module/process, language subset, polled GPIO | stable | preserve regression coverage |
| two same-module processes, spawn/send/receive | hardware-qualified experiment | rerun with the 2,048-byte C-stack reserve and confirm OOM behavior |
| two-process memory pressure | hardware-qualified experiment | repeat with allocation-failure injection and preserve the stack guard |
| spawn allocation failure | hardware-qualified experiment | preserve controlled `system_limit` behavior and stack guard |
| receive timeouts | build-qualified experiment | hardware timing and long-run test |
| timer memory pressure | hardware-qualified experiment | preserve timer behavior and the 2,048-byte stack reserve |
| byte-integer binary construction/exact matching | hardware-qualified experiment | preserve the deliberately narrow binary subset |
| binary allocation failure | hardware-qualified experiment | preserve controlled failure and stack guard |
| GPIO edge polling | build-qualified driver | physical rising/falling-edge tests |
| UART1 | build-qualified driver | physical PD5/PD6 loopback and timeout test |
| ADC | hardware smoke-tested driver | known-voltage measurements on PA2/A0 |
| I2C1 | build-qualified driver | device read/write and bus-recovery tests |
| SPI1 | build-qualified driver | PC6/PC7 loopback and device test |
| TIM1 PWM | hardware smoke-tested driver | frequency/duty measurements on PC3/PC4 |

“Build-qualified” means the final firmware passes AOT, instruction, ABI, and
size validation. It does not mean the electrical behavior has been verified.

Representative self-test image sizes measured on 2026-09-05:

| Image | Bytes | Flash remaining |
| --- | ---: | ---: |
| ADC | 59,048 | 4,440 |
| UART | 60,372 | 3,116 |
| SPI | 60,816 | 2,672 |
| PWM | 61,268 | 2,220 |
| I2C | 62,244 | 1,244 |
| GPIO IRQ | 62,360 | 1,128 |
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
The GPIO IRQ image is now tighter still after adding its pin and edge guards.

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

The spawn-allocation-failure image (`58,556` bytes) passed on hardware with the
injected allocation failure reported, the AtomVM self-test still passing, and a
final `ok`. It reported `4,152/6,312` bytes of heap in use (peak `4,152`),
`8` process-heap words with six free, and a C-stack peak of `656/1,432` bytes.

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
