%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_heap_oom_self_test).

-export([start/0]).

start() ->
    Result =
        try grow(0, []) of
            _ -> exhaustion_not_reached
        catch
            error:out_of_memory -> passed
        end,
    ch32v006:report(Result).

grow(N, Acc) ->
    grow(N + 1, [{N, N, N, N} | Acc]).
