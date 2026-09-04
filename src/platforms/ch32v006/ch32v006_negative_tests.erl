%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_negative_tests).

-export([run/2]).

-include("primitives.hrl").

run(FixtureDir, BuildDir) ->
    Cases = [
        {"processes", {unsupported_minimal_runtime_bif, {erlang, self, 0}}},
        {"message_send", {unsupported_minimal_runtime_primitive, ?PRIM_SEND}},
        {"message_receive", {unsupported_minimal_runtime_primitive, ?PRIM_PROCESS_SIGNAL_MESSAGES}},
        {"funs", {unsupported_minimal_runtime_primitive, ?PRIM_CALL_FUN}},
        {"floats", {unsupported_minimal_runtime_literal, float}},
        {"binaries", {unsupported_minimal_runtime_primitive, ?PRIM_MEMORY_ENSURE_FREE_WITH_ROOTS}},
        {"maps", {unsupported_minimal_runtime_literal, map}},
        {"big_integer",
            {unsupported_minimal_runtime_primitive, ?PRIM_ALLOC_BOXED_INTEGER_FRAGMENT}},
        {"dynamic_apply", {unsupported_minimal_runtime_external_call, {erlang, apply, 3}}}
    ],
    lists:foreach(fun(Case) -> rejects(Case, FixtureDir, BuildDir) end, Cases),
    io:format("CH32V006 unsupported-feature tests passed~n"),
    ok.

rejects({Name, Expected}, FixtureDir, BuildDir) ->
    Source = filename:join(FixtureDir, Name ++ ".erl"),
    {ok, Module} = compile:file(Source, [debug_info, {outdir, BuildDir}]),
    Beam = filename:join(BuildDir, atom_to_list(Module) ++ ".beam"),
    try jit_precompile:compile("riscv32e+minimal", BuildDir, false, Beam) of
        ok -> error({unsupported_feature_was_accepted, Name})
    catch
        error:Expected -> ok;
        error:Other -> error({unexpected_rejection, Name, Other})
    end.
