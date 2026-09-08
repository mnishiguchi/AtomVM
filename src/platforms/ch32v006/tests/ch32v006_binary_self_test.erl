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
    Binary = make_binary(A, B),
    Result =
        case Binary of
            <<16#12, 16#34, 16#56>> ->
                passed;
            _ ->
                failed
        end,
    ch32v006:report(Result).

make_binary(A, B) -> <<A:8, B:8, 16#56>>.
