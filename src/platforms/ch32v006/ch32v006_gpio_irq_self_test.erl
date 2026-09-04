%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_gpio_irq_self_test).

-export([start/0]).

-define(TEST_PIN, 51). % PD3

start() ->
    ok = gpio:init(?TEST_PIN),
    ok = gpio:set_pin_mode(?TEST_PIN, input),
    ok = gpio:set_pin_pull(?TEST_PIN, down),
    ok = gpio:set_pin_interrupt(?TEST_PIN, rising),
    Result = wait_for_edge(500),
    ok = gpio:clear_pin_interrupt(?TEST_PIN),
    ch32v006:report(Result).

wait_for_edge(0) -> failed;
wait_for_edge(Remaining) ->
    case gpio:interrupt_pending(?TEST_PIN) of
        true -> passed;
        false ->
            ch32v006:delay_ms(10),
            wait_for_edge(Remaining - 1)
    end.
