#
# This file is part of AtomVM.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

defmodule :ch32v006_external_send_badarg_self_test do
  @compile {:no_warn_undefined, [:ch32v006]}

  def start do
    try do
      send(:not_a_pid, :ping)
      :ch32v006.report(:failed)
    catch
      :error, :badarg -> :ch32v006.report(:passed)
    end
  end
end
