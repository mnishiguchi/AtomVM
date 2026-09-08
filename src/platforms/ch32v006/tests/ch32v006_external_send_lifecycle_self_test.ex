#
# This file is part of AtomVM.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule :ch32v006_external_send_lifecycle_self_test do
  @compile {:no_warn_undefined, [:ch32v006]}

  def start do
    child = spawn(__MODULE__, :child, [self()])

    receive do
      ^child -> :ok
    end

    # With MAX_PROCESSES=2, creating a replacement proves child was reclaimed.
    replacement = spawn(__MODULE__, :child, [self()])

    receive do
      ^replacement -> :ok
    end

    case send(child, :discard) do
      :discard -> :ch32v006.report(:passed)
      _ -> :ch32v006.report(:failed)
    end
  end

  def child(parent), do: send(parent, self())
end
