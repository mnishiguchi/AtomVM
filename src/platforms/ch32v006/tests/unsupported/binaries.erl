% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(binaries).
-export([make/1, start/0]).

start() ->
    ok.

make(Value) ->
    <<Value:8>>.
