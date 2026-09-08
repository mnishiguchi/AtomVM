% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(floats).
-export([start/0]).

start() ->
    add(1.0, 2.0).

add(A, B) when is_float(A), is_float(B) ->
    A + B.
