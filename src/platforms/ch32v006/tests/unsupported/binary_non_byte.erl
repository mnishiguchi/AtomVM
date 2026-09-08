% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(binary_non_byte).
-export([encode/2, start/0]).

start() -> ok.

encode(High, Low) -> <<High:4, Low:4>>.
