#
# This file is part of AtomVM.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule Button do
  @compile {:no_warn_undefined, [:gpio, :ch32v006]}

  @button 0
  @led 35

  def start do
    :gpio.init(@button)
    :gpio.set_pin_mode(@button, :input)
    :gpio.set_pin_pull(@button, :up)
    :gpio.init(@led)
    :gpio.set_pin_mode(@led, :output)
    poll()
  end

  defp poll do
    show(:gpio.digital_read(@button))
    :ch32v006.delay_ms(20)
    poll()
  end

  defp show(:low), do: :gpio.digital_write(@led, :high)
  defp show(:high), do: :gpio.digital_write(@led, :low)
end
