%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_timer_wrap_self_test).

-export([start/0, child/1]).

start() ->
    Child = spawn(?MODULE, child, [self()]),
    ok = ch32v006:prepare_systick_wrap(),
    receive
        _Unexpected ->
            ch32v006:report(failed)
    after 50 ->
        case ch32v006:systick_wrap_passed() of
            true ->
                Child ! ping,
                receive
                    {pong, Child} -> ch32v006:report(passed)
                after 200 ->
                    ch32v006:report(failed)
                end;
            false ->
                ch32v006:report(failed)
        end
    end.

child(Parent) ->
    receive
        ping -> Parent ! {pong, self()}
    end.
