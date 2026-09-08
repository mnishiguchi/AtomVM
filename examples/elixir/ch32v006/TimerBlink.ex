#
# This file is part of AtomVM.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule TimerBlink do
  @compile {:no_warn_undefined, [:gpio]}

  @led 35

  def start do
    :gpio.init(@led)
    :gpio.set_pin_mode(@led, :output)
    parent = self()
    spawn(__MODULE__, :blink, [parent, 1, 8])

    receive do
      :done -> :ok
    end
  end

  def blink(parent, _level, 0) do
    :gpio.digital_write(@led, :low)
    send(parent, :done)
  end

  def blink(parent, level, remaining) do
    :gpio.digital_write(@led, level)

    receive do
    after
      100 -> blink(parent, 1 - level, remaining - 1)
    end
  end
end
