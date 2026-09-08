%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_io_binary_self_test).

-export([start/0]).

start() ->
    Binary = ch32v006:io_binary_probe(),
    Copy = ch32v006:io_binary_copy(Binary),
    Result =
        case {ch32v006:io_binary_verify(Binary), ch32v006:io_binary_verify(Copy)} of
            {true, true} -> passed;
            _ -> failed
        end,
    ch32v006:report(Result).
