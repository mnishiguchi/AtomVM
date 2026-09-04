# Getting started with UIAPduino Pro Micro CH32V006

This Linux workflow builds AtomVM, creates a small Elixir application, embeds
it in firmware, flashes the board, and opens the SWIO console. Run commands
from the AtomVM repository root unless noted otherwise.

## 1. Prepare the tools

Install Erlang/OTP 28, Elixir, GNU Make, the RISC-V GCC/binutils toolchain, and
newlib headers. Then prepare the ch32fun revision used by CI:

```sh
git clone https://github.com/cnlohr/ch32fun.git /tmp/ch32fun
git -C /tmp/ch32fun checkout 618bba58c615ed29dc99e6ea92d869c914b6a8c0
make -C /tmp/ch32fun/minichlink
```

On Linux, install UIAP's minichlink udev rule if access to USB device
`1209:b806` is denied.

## 2. Build and flash the bundled image

```sh
make -C src/platforms/ch32v006 \
  CH32FUN=/tmp/ch32fun/ch32fun clean image

make -C src/platforms/ch32v006 \
  CH32FUN=/tmp/ch32fun/ch32fun \
  MINICHLINK=/tmp/ch32fun/minichlink \
  FLASH_IMAGE=build/images/AtomVM-uiapduino-pro-micro-ch32v006.bin \
  flash-uiap
```

The orange PC3 LED should blink briefly once per second.

## 3. Create an ExAtomVM project

Create the project outside this repository:

```sh
mix new uiap_blink --module UIAPBlink
cd uiap_blink
```

Add the AtomVM project configuration and ExAtomVM dependency to `mix.exs`:

```elixir
def project do
  [
    app: :uiap_blink,
    version: "0.1.0",
    elixir: "~> 1.19",
    deps: deps(),
    atomvm: [start: UIAPBlink]
  ]
end

defp deps do
  [
    {:exatomvm, git: "https://github.com/atomvm/ExAtomVM", branch: "main", runtime: false}
  ]
end
```

Replace `lib/uiap_blink.ex` with:

```elixir
defmodule UIAPBlink do
  @compile {:no_warn_undefined, [:gpio, :ch32v006]}
  @led 35

  def start do
    :gpio.init(@led)
    :gpio.set_pin_mode(@led, :output)
    loop(:high)
  end

  defp loop(level) do
    :gpio.digital_write(@led, level)
    :ch32v006.delay_ms(500)
    loop(toggle(level))
  end

  defp toggle(:high), do: :low
  defp toggle(:low), do: :high
end
```

Compile it:

```sh
mix deps.get
mix compile
```

Do not run `mix atomvm.packbeam` for this board. That task creates an `.avm`
archive, while this target embeds one startup BEAM directly in the firmware.
Use the BEAM produced by `mix compile` instead.

## 4. Build and flash the Elixir firmware

Return to the AtomVM repository root and replace `/path/to/uiap_blink` below
with the project directory:

```sh
make -C src/platforms/ch32v006 \
  CH32FUN=/tmp/ch32fun/ch32fun \
  START_BEAM_INPUT=/path/to/uiap_blink/_build/dev/lib/uiap_blink/ebin/Elixir.UIAPBlink.beam \
  IMAGE_BASENAME=AtomVM-uiapduino-pro-micro-ch32v006-uiap-blink \
  image

make -C src/platforms/ch32v006 \
  CH32FUN=/tmp/ch32fun/ch32fun \
  MINICHLINK=/tmp/ch32fun/minichlink \
  FLASH_IMAGE=build/images/AtomVM-uiapduino-pro-micro-ch32v006-uiap-blink.bin \
  flash-uiap
```

The platform build AOT-compiles the BEAM for RV32E and embeds it with AtomVM
in a single flashable BIN.

## 5. Monitor

```sh
make -C src/platforms/ch32v006 \
  CH32FUN=/tmp/ch32fun/ch32fun \
  MINICHLINK=/tmp/ch32fun/minichlink monitor-uiap
```

Open the terminal before resetting or reflashing if you want the boot banner.
The onboard programmer exposes HID/SWIO rather than `/dev/ttyACM*`, so `tio`
cannot monitor this console; the command above runs `minichlink -T`.

PC3 is LED pin `35`. Do not use PC0 (`32`), which controls programmer reset,
or PD1 (`49`) while using SWIO. See the [platform README](README.md) for the
supported runtime and GPIO boundary.
