% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(binary_copy).
-export([copy/2, start/0]).

start() -> ok.

copy(Prefix, Binary) -> <<Prefix:8, Binary/binary>>.
