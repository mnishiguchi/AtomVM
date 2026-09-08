% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(binary_utf8).
-export([encode/1, start/0]).

start() -> ok.

encode(Value) -> <<Value/utf8>>.
