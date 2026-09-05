%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_i2c_self_test).

-export([start/0]).

start() ->
    ClockGuard = guard_invalid_clock(),
    AddressGuard = guard_invalid_address(),
    ok = i2c:init(100000),
    ScanResult = scan(16#08),
    ch32v006:report(verify(ClockGuard, AddressGuard, ScanResult)).

guard_invalid_clock() ->
    try i2c:init(0) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

guard_invalid_address() ->
    try i2c:probe(7) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

verify(passed, passed, passed) ->
    passed;
verify(_, _, _) ->
    failed.

scan(16#78) ->
    failed;
scan(Address) ->
    case i2c:probe(Address) of
        ok -> passed;
        error -> scan(Address + 1)
    end.
