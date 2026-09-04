%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_timer_self_test).

-export([start/0, child/1]).

start() ->
    TimeoutResult =
        receive
            impossible -> failed
        after 25 ->
            passed
        end,
    Parent = self(),
    Child = spawn(?MODULE, child, [Parent]),
    Child ! ping,
    CancelResult =
        receive
            {pong, Child} -> passed
        after 200 ->
            failed
        end,
    Child ! stop,
    ch32v006:report(combine(TimeoutResult, CancelResult)).

child(Parent) ->
    receive
        ping ->
            Parent ! {pong, self()},
            child(Parent);
        stop ->
            ok
    end.

combine(passed, passed) -> passed;
combine(_, _) -> failed.
