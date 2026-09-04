%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_adc_self_test).

-export([start/0]).

start() ->
    _Value = adc:read(0),
    ch32v006:report(passed).
