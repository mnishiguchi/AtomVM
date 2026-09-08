%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_timer_self_test).

-export([start/0, child/1]).

start() ->
    receive
        impossible ->
            ch32v006:report(failed)
    after 25 ->
        Parent = self(),
        Child = spawn(?MODULE, child, [Parent]),
        Child ! ping,
        receive
            {pong, Child} -> ch32v006:report(passed)
        after 200 ->
            ch32v006:report(failed)
        end
    end.

child(Parent) ->
    receive
        ping -> Parent ! {pong, self()}
    end.
