%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_process_stress_self_test).

-export([start/0, child/2]).

% Reclaim the child context and mailbox between 256 numbered exchanges.
start() ->
    run(256).

run(0) ->
    ch32v006:report(passed);
run(Remaining) ->
    Child = spawn_child(Remaining, 20),
    receive
        {done, Child, Remaining} -> run(Remaining - 1)
    after 200 ->
        ch32v006:report(failed)
    end.

spawn_child(_Sequence, 0) ->
    ch32v006:report(failed);
spawn_child(Sequence, Attempts) ->
    try spawn(?MODULE, child, [self(), Sequence]) of
        Child -> Child
    catch
        error:system_limit ->
            % A reply can arrive before the previous child has finished exiting.
            % Yield to it, but fail if its process slot is never reclaimed.
            receive
            after 1 -> spawn_child(Sequence, Attempts - 1)
            end
    end.

child(Parent, Sequence) ->
    Parent ! {done, self(), Sequence}.
