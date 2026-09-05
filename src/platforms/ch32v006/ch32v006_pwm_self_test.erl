%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_pwm_self_test).

-export([start/0]).

start() ->
    ok = pwm:init(1000),
    ok = pwm:set_duty(3, 100),
    ch32v006:delay_ms(300),
    ok = pwm:set_duty(3, 900),
    ch32v006:delay_ms(300),
    ok = pwm:set_duty(3, 0),
    ch32v006:report(passed).
