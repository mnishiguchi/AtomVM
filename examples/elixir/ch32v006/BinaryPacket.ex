#
# This file is part of AtomVM.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule BinaryPacket do
  def start do
    first =
      case :atomvm.platform() do
        :ch32v006 -> 0x12
        _ -> 0
      end

    <<0x12, 0x34, 0x46>> = packet(first, 0x34)
    :ok
  end

  defp packet(first, second) do
    checksum = first + second
    <<first, second, checksum>>
  end
end
