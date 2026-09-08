%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_timer_production_soak_self_test).

-export([start/0, child/1]).

% At 48 MHz with SysTick at HCLK/8, two 32-bit wraps take about
% 1,431,656 ms. Wait beyond that boundary without repositioning the counter.
-define(SOAK_MS, 1432000).

start() ->
    Child = spawn(?MODULE, child, [self()]),
    receive
        {passed, Child} -> ch32v006:report(passed);
        _Unexpected -> ch32v006:report(failed)
    after ?SOAK_MS + 5000 ->
        ch32v006:report(failed)
    end.

child(Parent) ->
    receive
    after ?SOAK_MS ->
        case ch32v006:production_time_soak_passed() of
            true -> Parent ! {passed, self()};
            false -> Parent ! failed
        end
    end.
