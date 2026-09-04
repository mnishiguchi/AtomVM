# CH32V006 Elixir examples

- `Blink.ex` toggles the onboard PC3 LED every 500 ms.
- `Button.ex` lights PC3 while PA0/D0 is connected to GND. PA0 uses its
  internal pull-up, so a push button needs no external resistor.

Both examples target the one-module constrained runtime and use the blocking
`:ch32v006.delay_ms/1` helper. For tool setup, firmware creation, flashing, and
monitoring, follow the platform [getting-started guide](../../../src/platforms/ch32v006/docs/getting-started.md).

To try either file directly, compile it and pass its BEAM to the platform
build. For example:

```sh
mkdir -p /tmp/ch32v006-elixir
elixirc -o /tmp/ch32v006-elixir examples/elixir/ch32v006/Blink.ex

make -C src/platforms/ch32v006 \
  CH32FUN=/tmp/ch32fun/ch32fun \
  START_BEAM_INPUT=/tmp/ch32v006-elixir/Elixir.Blink.beam \
  IMAGE_BASENAME=AtomVM-uiapduino-pro-micro-ch32v006-elixir-blink image
```
