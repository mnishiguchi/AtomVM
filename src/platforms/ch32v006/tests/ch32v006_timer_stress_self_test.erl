%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_timer_stress_self_test).

-export([start/0, child/1]).

% 256 expired waits and 256 bounded message receives, with numbered replies
% to reject stale delivery. The delays total at least 6.4 seconds.
start() ->
    Child = spawn(?MODULE, child, [self()]),
    run(256, Child).

run(0, Child) ->
    Child ! stop,
    ch32v006:report(passed);
run(Remaining, Child) ->
    receive
        _Unexpected -> ch32v006:report(failed)
    after 25 ->
        Child ! {ping, Remaining},
        receive
            {pong, Child, Remaining} -> run(Remaining - 1, Child)
        after 200 ->
            ch32v006:report(failed)
        end
    end.

child(Parent) ->
    receive
        {ping, Sequence} ->
            Parent ! {pong, self(), Sequence},
            child(Parent);
        stop ->
            ok
    end.
