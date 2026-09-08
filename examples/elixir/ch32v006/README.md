# CH32V006 Elixir examples

- `Blink.ex` toggles the onboard PC3 LED every 500 ms.
- `Button.ex` lights PC3 while PA0/D0 is connected to GND. PA0 uses its
  internal pull-up, so a push button needs no external resistor.
- `BinaryPacket.ex` constructs and verifies a three-byte packet. It exercises
  the optional byte-binary profile without external wiring.
- `TimerBlink.ex` uses two processes, messages, and receive timeouts to blink
  PC3 eight times. It needs the qualified two-process timer profile.

`Blink.ex` and `Button.ex` use the blocking `:ch32v006.delay_ms/1` helper.
`TimerBlink.ex` exercises scheduler-aware timing instead. All four target the
one-module constrained runtime. For tool setup, firmware creation, flashing,
and monitoring, follow the platform
[getting-started guide](../../../src/platforms/ch32v006/docs/getting-started.md).

To try an example directly, compile it and pass its BEAM to the platform build.
For example:

```sh
mkdir -p /tmp/ch32v006-elixir
elixirc -o /tmp/ch32v006-elixir examples/elixir/ch32v006/Blink.ex

make -C src/platforms/ch32v006 \
  CH32FUN=/tmp/ch32fun/ch32fun \
  START_BEAM_INPUT=/tmp/ch32v006-elixir/Elixir.Blink.beam \
  IMAGE_BASENAME=AtomVM-uiapduino-pro-micro-ch32v006-elixir-blink image
```

For `TimerBlink.ex`, add the qualified timer profile settings to the `make`
command:

```sh
CONCURRENCY=1 TIMERS=1 MAX_PROCESSES=2 C_STACK_RESERVE_BYTES=2048
```

For `BinaryPacket.ex`, compile that module instead and add `BINARIES=1` to the
`make` command. A successful run prints `ok` and changes to the short success
blink pattern.
