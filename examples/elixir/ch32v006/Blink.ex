#
# This file is part of AtomVM.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule Blink do
  @compile {:no_warn_undefined, [:gpio, :ch32v006]}

  @led 35

  def start do
    :gpio.init(@led)
    :gpio.set_pin_mode(@led, :output)
    blink(:high)
  end

  defp blink(level) do
    :gpio.digital_write(@led, level)
    :ch32v006.delay_ms(500)
    blink(toggle(level))
  end

  defp toggle(:high), do: :low
  defp toggle(:low), do: :high
end
