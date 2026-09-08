% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(funs).
-export([start/0]).

start() ->
    Fun = make(ok),
    Fun().

make(Value) ->
    fun() -> Value end.
