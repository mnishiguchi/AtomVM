% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(binary_subbinary).
-export([start/0, tail/1]).

start() -> ok.

tail(<<_:8, Rest/binary>>) -> Rest.
