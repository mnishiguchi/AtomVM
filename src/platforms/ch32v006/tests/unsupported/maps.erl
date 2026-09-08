% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(maps).
-export([start/0]).

start() ->
    make(ok).

make(Value) ->
    #{value => Value}.
