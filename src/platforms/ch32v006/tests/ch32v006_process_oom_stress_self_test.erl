%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_process_oom_stress_self_test).

-export([start/0, child/1]).

% Repeat failed context allocation followed by successful spawn, messaging,
% termination, and process-slot reuse.
start() ->
    run(64).

run(0) ->
    ch32v006:report(passed);
run(Remaining) ->
    ok = ch32v006:fail_next_allocation(),
    try spawn(?MODULE, child, [self()]) of
        _UnexpectedChild ->
            ch32v006:report(failed)
    catch
        error:out_of_memory ->
            Child = spawn(?MODULE, child, [self()]),
            receive
                Child ->
                    % Let the child finish context teardown before arming the
                    % next allocator failure.
                    receive
                    after 1 -> run(Remaining - 1)
                    end
            after 200 ->
                ch32v006:report(failed)
            end
    end.

child(Parent) ->
    Parent ! self().
