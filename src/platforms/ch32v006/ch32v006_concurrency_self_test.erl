%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_concurrency_self_test).

-export([start/0, child/1]).

start() ->
    Parent = self(),
    Child = spawn(?MODULE, child, [Parent]),
    Child ! ping,
    receive
        {pong, Child} -> ok
    end,
    ok = ch32v006:report(passed),
    LimitResult =
        try spawn(?MODULE, child, [Parent]) of
            _UnexpectedPid -> failed
        catch
            error:system_limit -> passed
        end,
    ok = ch32v006:report(LimitResult),
    Child ! stop,
    receive
        {stopped, Child} -> ch32v006:report(LimitResult)
    end.

child(Parent) ->
    receive
        ping ->
            Parent ! {pong, self()},
            child(Parent);
        stop ->
            Parent ! {stopped, self()}
    end.
