%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_i2c_self_test).

-export([start/0]).

start() ->
    ok = i2c:init(100000),
    ch32v006:report(scan(16#08)).

scan(16#78) ->
    failed;
scan(Address) ->
    case i2c:probe(Address) of
        ok -> passed;
        error -> scan(Address + 1)
    end.
