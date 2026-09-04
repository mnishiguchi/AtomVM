%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_binary_self_test).

-export([start/0]).

start() ->
    A = 16#12,
    B = 16#34,
    Binary = <<A:8, B:8, 16#56>>,
    Result =
        case Binary of
            <<16#12, 16#34, Rest/binary>> ->
                verify(Rest, byte_size(Rest), bit_size(Rest));
            _ ->
                failed
        end,
    ch32v006:report(Result).

verify(<<16#56>>, 1, 8) -> passed;
verify(_, _, _) -> failed.
