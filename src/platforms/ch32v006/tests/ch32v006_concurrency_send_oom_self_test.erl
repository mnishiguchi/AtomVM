%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_concurrency_send_oom_self_test).

-export([start/0, child/1]).

start() ->
    Parent = self(),
    Child = spawn(?MODULE, child, [Parent]),
    Result = run_cycles(Child),
    Child ! stop,
    ch32v006:report(Result).

run_cycles(Child) ->
    case run_cycle(Child) of
        passed ->
            case run_cycle(Child) of
                passed -> run_cycle(Child);
                failed -> failed
            end;
        failed ->
            failed
    end.

run_cycle(Child) ->
    ok = ch32v006:fail_next_allocation(),
    Result =
        try Child ! ping of
            _ -> failed
        catch
            error:out_of_memory ->
                Child ! ping,
                receive
                    pong -> passed
                end
        end,
    Result.

child(Parent) ->
    receive
        ping ->
            Parent ! pong,
            child(Parent);
        stop ->
            ok
    end.
