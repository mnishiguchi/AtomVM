%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_gpio_self_test).

-export([start/0]).

% PC3 in ch32fun pin numbering.
-define(LED_BUILTIN, 35).
% PA0 / D0, exposed and unloaded on UIAPduino V1.1.
-define(GPIO_TEST_PIN, 0).

start() ->
    Result = verify(atomvm:platform(), exercise_gpio(), pc0_guard(), swio_guard()),
    ch32v006:report(Result).

exercise_gpio() ->
    ok = gpio:init(?GPIO_TEST_PIN),
    ok = gpio:set_pin_pull(?GPIO_TEST_PIN, up),
    PullUp = gpio:digital_read(?GPIO_TEST_PIN),
    ok = gpio:set_pin_pull(?GPIO_TEST_PIN, down),
    PullDown = gpio:digital_read(?GPIO_TEST_PIN),
    ok = gpio:set_pin_mode(?GPIO_TEST_PIN, output),
    ok = gpio:digital_write(?GPIO_TEST_PIN, 1),
    OutputHigh = gpio:digital_read(?GPIO_TEST_PIN),
    ok = gpio:digital_write(?GPIO_TEST_PIN, 0),
    OutputLow = gpio:digital_read(?GPIO_TEST_PIN),
    ok = gpio:deinit(?GPIO_TEST_PIN),
    {PullUp, PullDown, OutputHigh, OutputLow}.

pc0_guard() ->
    try gpio:set_pin_pull(32, up) of
        _ -> guard_failed
    catch
        error:badarg -> guard_passed
    end.

swio_guard() ->
    try gpio:set_pin_mode(49, output) of
        _ -> guard_failed
    catch
        error:badarg -> guard_passed
    end.

verify(ch32v006, {high, low, high, low}, guard_passed, guard_passed) ->
    passed;
verify(_, _, _, _) ->
    failed.
