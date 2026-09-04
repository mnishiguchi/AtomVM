% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(dynamic_apply).
-export([start/0]).

start() ->
    invoke(erlang, length, [[]]).

invoke(Module, Function, Arguments) ->
    apply(Module, Function, Arguments).
