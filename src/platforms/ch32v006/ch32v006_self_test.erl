%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_self_test).

-export([start/0]).

start() ->
    UndefGuard = guard_undef(),
    BadarithGuard = guard_badarith(0),
    Churn = churn(32, []),
    Containers = inspect([alpha, beta], {left, right}),
    Result = verify(
        ready,
        UndefGuard,
        BadarithGuard,
        arithmetic(17, 5),
        Churn,
        Containers,
        done
    ),
    ch32v006:report(Result).

arithmetic(A, B) ->
    {A + B, A - B, A * B, A div B, A rem B}.

churn(0, Acc) ->
    Acc;
churn(N, _Acc) ->
    churn(N - 1, [{N, N, N}]).

inspect(List, Tuple) ->
    {length(List), hd(List), tl(List), element(2, Tuple), tuple_size(Tuple)}.

guard_undef() ->
    try ch32v006_missing:call() of
        _ -> guard_failed
    catch
        error:undef -> guard_passed
    end.

guard_badarith(Zero) ->
    try 1 div Zero of
        _ -> guard_failed
    catch
        error:badarith -> guard_passed
    end.

verify(
    ready,
    guard_passed,
    guard_passed,
    {22, 12, 85, 3, 2},
    [{1, 1, 1}],
    {2, alpha, [beta], right, 2},
    done
) ->
    passed;
verify(_, _, _, _, _, _, _) ->
    failed.
