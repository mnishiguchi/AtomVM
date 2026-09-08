%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_combined_self_test).

-export([start/0, blink/3]).

-define(LED, 35).

start() ->
    ok = gpio:init(?LED),
    ok = gpio:set_pin_mode(?LED, output),
    Child = spawn(?MODULE, blink, [self(), high, 8]),
    receive
        {done, Child} -> ch32v006:report(passed)
    after 2000 ->
        ch32v006:report(failed)
    end.

blink(Parent, _Level, 0) ->
    ok = gpio:digital_write(?LED, low),
    Parent ! {done, self()};
blink(Parent, Level, Remaining) ->
    ok = gpio:digital_write(?LED, Level),
    receive
    after 100 -> blink(Parent, toggle(Level), Remaining - 1)
    end.

toggle(high) -> low;
toggle(low) -> high.
