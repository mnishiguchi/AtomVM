%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_pwm_self_test).

-export([start/0]).

start() ->
    FrequencyGuard = guard_invalid_frequency(),
    ok = pwm:init(1000),
    ChannelGuard = guard_invalid_channel(),
    DutyGuard = guard_invalid_duty(),
    ok = pwm:set_duty(3, 100),
    ch32v006:delay_ms(300),
    ok = pwm:set_duty(3, 900),
    ch32v006:delay_ms(300),
    ok = pwm:set_duty(3, 0),
    ch32v006:report(verify(FrequencyGuard, ChannelGuard, DutyGuard)).

guard_invalid_frequency() ->
    try pwm:init(0) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

guard_invalid_channel() ->
    try pwm:set_duty(2, 500) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

guard_invalid_duty() ->
    try pwm:set_duty(3, 1001) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

verify(passed, passed, passed) ->
    passed;
verify(_, _, _) ->
    failed.
