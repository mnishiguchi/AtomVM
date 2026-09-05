%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_uart_self_test).

-export([start/0]).

start() ->
    ok = uart:init(115200),
    1 = uart:write(<<16#A5>>),
    ch32v006:delay_ms(2),
    Result =
        case uart:read() of
            16#A5 -> passed;
            _ -> failed
        end,
    ch32v006:report(Result).
