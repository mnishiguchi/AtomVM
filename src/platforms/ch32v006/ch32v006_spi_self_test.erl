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
        case spi:transfer(<<16#A5, 16#5A>>) of
            <<16#A5, 16#5A>> -> passed;
            _ -> failed
        end,
    ch32v006:report(Result).
