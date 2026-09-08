%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_binary_oom_self_test).

-export([start/0]).

start() ->
    ok = ch32v006:fail_next_allocation(),
    Result =
        try ch32v006:binary_allocation_probe() of
            _ -> allocation_succeeded
        catch
            error:out_of_memory -> passed
        end,
    ch32v006:report(Result).
