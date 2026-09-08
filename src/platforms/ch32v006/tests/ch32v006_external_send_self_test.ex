#
# This file is part of AtomVM.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule :ch32v006_external_send_self_test do
  @compile {:no_warn_undefined, [:ch32v006]}

  def start do
    :ch32v006.fail_next_allocation()

    try do
      send(self(), :ping)
      :ch32v006.report(:failed)
    catch
      :error, :out_of_memory ->
        case send(self(), :ping) do
          :ping ->
            receive do
              :ping -> :ch32v006.report(:passed)
            end

          _ ->
            :ch32v006.report(:failed)
        end
    end
  end
end
