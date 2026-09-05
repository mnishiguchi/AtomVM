%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_spi_self_test).

-export([start/0]).

start() ->
    Result = verify(low_clock_guard(), transfer_byte_loopback()),
    ch32v006:report(Result).

low_clock_guard() ->
    try spi:init(1, 0) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

transfer_byte_loopback() ->
    ok = spi:init(1000000, 0),
    case spi:transfer_byte(16#A5) of
        16#A5 -> passed;
        _ -> failed
    end.

verify(passed, passed) ->
    passed;
verify(_, _) ->
    failed.
