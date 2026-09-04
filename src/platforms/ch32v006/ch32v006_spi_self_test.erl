%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_spi_self_test).

-export([start/0]).

start() ->
    ok = spi:init(1000000, 0),
    Result =
        case spi:transfer_byte(16#A5) of
            16#A5 -> passed;
            _ -> failed
        end,
    ch32v006:report(Result).
