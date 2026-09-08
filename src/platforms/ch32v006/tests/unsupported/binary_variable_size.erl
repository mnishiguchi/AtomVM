% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(binary_variable_size).
-export([encode/2, start/0]).

start() -> ok.

encode(Value, Size) -> <<Value:Size/unit:8>>.
