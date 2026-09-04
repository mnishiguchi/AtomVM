% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(processes).
-export([start/0]).

start() ->
    self().
