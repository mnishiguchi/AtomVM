%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_arithmetic_boundary_self_test).

-export([start/0]).

start() ->
    Max = ch32v006:small_int_max(),
    Min = 0 - Max - 1,
    Result = verify(
        expect_overflow_add(Max),
        expect_overflow_sub(Min),
        expect_overflow_mul(Max),
        expect_overflow_div(Min),
        safe_remainder(Min),
        {
            expect_badarith(add, not_an_integer),
            expect_badarith(sub, not_an_integer),
            expect_badarith(mul, not_an_integer),
            expect_badarith(divide, 0),
            expect_badarith(remainder, 0)
        }
    ),
    ch32v006:report(Result).

expect_overflow_add(Value) ->
    try Value + 1 of
        _Result -> failed
    catch
        error:overflow -> passed
    end.

expect_overflow_sub(Value) ->
    try Value - 1 of
        _Result -> failed
    catch
        error:overflow -> passed
    end.

expect_overflow_mul(Value) ->
    try Value * 2 of
        _Result -> failed
    catch
        error:overflow -> passed
    end.

expect_overflow_div(Value) ->
    try Value div -1 of
        _Result -> failed
    catch
        error:overflow -> passed
    end.

safe_remainder(Value) ->
    Value rem -1.

expect_badarith(Operation, Value) ->
    try badarith_operation(Operation, Value) of
        _Result -> failed
    catch
        error:badarith -> passed
    end.

badarith_operation(add, Value) -> Value + 1;
badarith_operation(sub, Value) -> Value - 1;
badarith_operation(mul, Value) -> Value * 2;
badarith_operation(divide, Value) -> 1 div Value;
badarith_operation(remainder, Value) -> 1 rem Value.

verify(passed, passed, passed, passed, 0, {passed, passed, passed, passed, passed}) ->
    passed;
verify(_, _, _, _, _, _) ->
    failed.
