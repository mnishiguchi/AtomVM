%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_adc_self_test).

-export([start/0]).

start() ->
    Result =
        case adc:read(0) of
            Value when Value >= 0, Value =< 4095 -> passed;
            _ -> failed
        end,
    ch32v006:report(Result).
