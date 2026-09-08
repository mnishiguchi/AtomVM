% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
-module(message_receive).
-export([start/0]).

start() ->
    receive
        Message -> Message
    end.
