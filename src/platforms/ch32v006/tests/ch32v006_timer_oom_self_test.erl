%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_timer_oom_self_test).

-export([start/0, child/1]).

start() ->
    Parent = self(),
    Child = spawn(?MODULE, child, [Parent]),
    Child ! inject,
    Result =
        receive
            impossible ->
                failed
        after 25 ->
            receive
                allocation_failed -> passed
            end
        end,
    ch32v006:report(Result).

child(Parent) ->
    receive
        inject ->
            ok = ch32v006:fail_next_allocation(),
            try Parent ! impossible of
                _ ->
                    Parent ! allocation_succeeded
            catch
                error:out_of_memory ->
                    Parent ! allocation_failed
            end
    end.
