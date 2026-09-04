%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_minimal).

-export([start/0]).

% PC3 in ch32fun pin numbering.
-define(LED_BUILTIN, 35).

start() ->
    gpio:init(?LED_BUILTIN),
    gpio:set_pin_mode(?LED_BUILTIN, output),
    blink().

blink() ->
    gpio:digital_write(?LED_BUILTIN, high),
    ch32v006:delay_ms(100),
    gpio:digital_write(?LED_BUILTIN, low),
    ch32v006:delay_ms(900),
    blink().
