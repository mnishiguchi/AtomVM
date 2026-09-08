%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_binary_self_test).

-export([start/0]).

start() ->
    Value =
        case atomvm:platform() of
            ch32v006 -> 255;
            _ -> 0
        end,
    passed = verify([
        exact_match(Value),
        mismatch(Value),
        segment_values()
    ]),
    ch32v006:report(allocation_failure()).

make_byte(Value) -> <<Value:8>>.

exact_match(Value) ->
    case make_byte(Value) of
        <<255>> -> passed;
        _ -> failed
    end.

mismatch(Value) ->
    case make_byte(Value) of
        <<0>> -> failed;
        _ -> passed
    end.

segment_values() ->
    case {make_byte(-1), make_byte(256), invalid_value(not_an_integer)} of
        {<<255>>, <<0>>, passed} -> passed;
        _ -> failed
    end.

invalid_value(Value) ->
    try make_byte(Value) of
        _ -> failed
    catch
        error:badarg -> passed
    end.

allocation_failure() ->
    try retain_binaries(255, []) of
        _ -> failed
    catch
        error:out_of_memory -> passed
    end.

retain_binaries(0, Acc) -> Acc;
retain_binaries(Count, Acc) ->
    Binary = make_byte(Count),
    retain_binaries(Count - 1, [Binary | Acc]).

verify([passed, passed, passed]) -> passed;
verify(_) -> failed.
