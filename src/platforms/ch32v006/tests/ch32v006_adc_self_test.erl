%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_adc_self_test).

-export([start/0]).

start() ->
    LowChannelGuard = invalid_channel(-1),
    HighChannelGuard = invalid_channel(8),
    ValueResult =
        case adc:read(0) of
            Value when Value >= 0, Value =< 4095 -> passed;
            _ -> failed
        end,
    Result = verify(LowChannelGuard, HighChannelGuard, ValueResult),
    ch32v006:report(Result).

invalid_channel(Channel) ->
    try adc:read(Channel) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

verify(passed, passed, passed) ->
    passed;
verify(_, _, _) ->
    failed.
