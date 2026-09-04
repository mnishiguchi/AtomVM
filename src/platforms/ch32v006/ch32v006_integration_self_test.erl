%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_integration_self_test).

-export([start/0, child/1]).

-define(IRQ_PIN, 51). % PD3

start() ->
    ok = gpio:init(?IRQ_PIN),
    ok = gpio:set_pin_mode(?IRQ_PIN, input),
    ok = gpio:set_pin_pull(?IRQ_PIN, down),
    ok = gpio:set_pin_interrupt(?IRQ_PIN, rising),
    Result = test_timer(),
    ok = gpio:clear_pin_interrupt(?IRQ_PIN),
    ch32v006:report(Result).

test_timer() ->
    receive
        unexpected -> failed
    after 25 ->
        test_concurrency()
    end.

test_concurrency() ->
    Parent = self(),
    Child = spawn(?MODULE, child, [Parent]),
    Child ! ping,
    receive
        {pong, Child} ->
            Child ! stop,
            receive
                {stopped, Child} -> test_binary()
            after 200 ->
                failed
            end
    after 200 ->
        Child ! stop,
        failed
    end.

child(Parent) ->
    receive
        ping ->
            Parent ! {pong, self()},
            child(Parent);
        stop ->
            Parent ! {stopped, self()},
            ok
    end.

test_binary() ->
    A = 16#12,
    B = 16#34,
    Binary = <<A:8, B:8, 16#56>>,
    case Binary of
        <<16#12, 16#34, Rest/binary>> ->
            case {Rest, byte_size(Rest), bit_size(Rest)} of
                {<<16#56>>, 1, 8} -> test_uart();
                _ -> failed
            end;
        _ ->
            failed
    end.

test_uart() ->
    ok = uart:init(115200),
    case uart:write(<<16#A5>>) of
        1 ->
            ch32v006:delay_ms(2),
            case uart:read() of
                16#A5 -> test_adc();
                _ -> failed
            end;
        _ ->
            failed
    end.

test_adc() ->
    case adc:read(0) of
        error -> failed;
        _ -> test_i2c()
    end.

test_i2c() ->
    ok = i2c:init(100000),
    case scan_i2c(16#08) of
        passed -> test_spi();
        failed -> failed
    end.

scan_i2c(16#78) ->
    failed;
scan_i2c(Address) ->
    case i2c:probe(Address) of
        ok -> passed;
        error -> scan_i2c(Address + 1)
    end.

test_spi() ->
    ok = spi:init(1000000, 0),
    case spi:transfer(<<16#A5, 16#5A>>) of
        <<16#A5, 16#5A>> -> test_pwm();
        _ -> failed
    end.

test_pwm() ->
    ok = pwm:init(1000),
    ok = pwm:set_duty(3, 200),
    ch32v006:delay_ms(100),
    ok = pwm:set_duty(3, 800),
    ch32v006:delay_ms(100),
    ok = pwm:set_duty(3, 0),
    ok = gpio:set_pin_mode(35, output),
    test_gpio_irq(500).

test_gpio_irq(0) ->
    failed;
test_gpio_irq(Remaining) ->
    case gpio:interrupt_pending(?IRQ_PIN) of
        true -> passed;
        false ->
            ch32v006:delay_ms(10),
            test_gpio_irq(Remaining - 1)
    end.
