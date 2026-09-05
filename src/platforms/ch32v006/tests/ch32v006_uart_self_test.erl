%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_uart_self_test).

-export([start/0]).

start() ->
    BaudGuard = guard_invalid_baud(),
    HighBaudGuard = guard_high_baud(),
    ok = uart:init(115200),
    1 = uart:write(<<16#A5>>),
    ch32v006:delay_ms(2),
    LoopbackResult =
        case uart:read() of
            16#A5 -> passed;
            _ -> failed
        end,
    Result = verify(BaudGuard, HighBaudGuard, LoopbackResult),
    ch32v006:report(Result).

guard_invalid_baud() ->
    try uart:init(0) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

guard_high_baud() ->
    try uart:init(2000001) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

verify(passed, passed, passed) ->
    passed;
verify(_, _, _) ->
    failed.
