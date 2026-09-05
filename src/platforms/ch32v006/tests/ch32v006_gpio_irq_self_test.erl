%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_gpio_irq_self_test).

-export([start/0]).

% PD3
-define(TEST_PIN, 51).

start() ->
    PinGuard = guard_invalid_pin(),
    EdgeGuard = guard_invalid_edge(),
    ok = gpio:init(?TEST_PIN),
    ok = gpio:set_pin_mode(?TEST_PIN, input),
    ok = gpio:set_pin_pull(?TEST_PIN, down),
    ok = gpio:set_pin_interrupt(?TEST_PIN, rising),
    Result = wait_for_edge(500),
    ok = gpio:clear_pin_interrupt(?TEST_PIN),
    ch32v006:report(verify(PinGuard, EdgeGuard, Result)).

guard_invalid_pin() ->
    try gpio:set_pin_interrupt(32, rising) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

guard_invalid_edge() ->
    try gpio:set_pin_interrupt(?TEST_PIN, invalid_edge) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

verify(passed, passed, passed) ->
    passed;
verify(_, _, _) ->
    failed.

wait_for_edge(0) ->
    failed;
wait_for_edge(Remaining) ->
    case gpio:interrupt_pending(?TEST_PIN) of
        true ->
            passed;
        false ->
            ch32v006:delay_ms(10),
            wait_for_edge(Remaining - 1)
    end.
