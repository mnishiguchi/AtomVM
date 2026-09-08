#
# This file is part of AtomVM.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule BinaryPacket do
  def start do
    <<0x12, 0x34, 0x46>> = packet(0x12, 0x34)
    :ok
  end

  defp packet(first, second) do
    checksum = first + second
    <<first, second, checksum>>
  end
end
