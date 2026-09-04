%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

-module(jit_riscv32e_tests).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-include("jit/include/jit.hrl").

-define(VARIANT, (?JIT_VARIANT_PIC bor ?JIT_VARIANT_RV32E)).
-define(MINIMAL_VARIANT, (?VARIANT bor ?JIT_VARIANT_MINIMAL)).

available_registers_test() ->
    State = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    ?assertEqual([t2, t1, t0], jit_riscv32e:available_regs(State)).

zmmul_backend_does_not_advertise_hardware_division_test() ->
    Exports = jit_riscv32e:module_info(exports),
    ?assertEqual(false, lists:member({div_, 3}, Exports)),
    ?assertEqual(false, lists:member({rem_, 3}, Exports)).

minimal_runtime_rejects_missing_primitive_test() ->
    State = jit_riscv32e:new(
        ?MINIMAL_VARIANT, jit_stream_binary, jit_stream_binary:new(0)
    ),
    ?assertError(
        {unsupported_minimal_runtime_primitive, 17},
        jit_riscv32e:call_primitive(State, 17, [ctx, jit_state])
    ).

minimal_runtime_rejects_missing_bif_test() ->
    State = jit_riscv32e:new(
        ?MINIMAL_VARIANT, jit_stream_binary, jit_stream_binary:new(0)
    ),
    ?assertError(
        {unsupported_minimal_runtime_bif, {erlang, self, 0}},
        jit_riscv32e:validate_bif(State, {erlang, self, 0})
    ).

minimal_runtime_rejects_dynamic_apply_test() ->
    State = jit_riscv32e:new(
        ?MINIMAL_VARIANT, jit_stream_binary, jit_stream_binary:new(0)
    ),
    ?assertError(
        {unsupported_minimal_runtime_external_call, {erlang, apply, 3}},
        jit_riscv32e:validate_external_call(State, {erlang, apply, 3})
    ).

regular_rv32e_keeps_complete_native_interface_test() ->
    State = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    {_, _} = jit_riscv32e:call_primitive(State, 17, [ctx, jit_state]),
    ok = jit_riscv32e:validate_bif(State, {erlang, self, 0}),
    ok = jit_riscv32e:validate_external_call(State, {erlang, apply, 3}).

call_primitive_test() ->
    State0 = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    {State1, ResultReg} = jit_riscv32e:call_primitive(State0, 0, [ctx, jit_state]),
    ?assertEqual(t2, ResultReg),
    ?assertEqual(
        <<
            % lw t2,0(a2)
            16#83,
            16#23,
            16#06,
            16#00,
            % addi sp,sp,-16
            16#41,
            16#11,
            % sw ra,0(sp)
            16#06,
            16#c0,
            % sw a0,4(sp)
            16#2a,
            16#c2,
            % sw a1,8(sp)
            16#2e,
            16#c4,
            % sw a2,12(sp)
            16#32,
            16#c6,
            % jalr t2
            16#82,
            16#93,
            % mv t2,a0
            16#aa,
            16#83,
            % lw ra,0(sp)
            16#82,
            16#40,
            % lw a0,4(sp)
            16#12,
            16#45,
            % lw a1,8(sp)
            16#a2,
            16#45,
            % lw a2,12(sp)
            16#32,
            16#46,
            % addi sp,sp,16
            16#41,
            16#01
        >>,
        jit_riscv32e:stream(State1)
    ).

six_argument_tail_call_test() ->
    State0 = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    State1 = jit_riscv32e:call_primitive_last(State0, 4, [
        ctx, jit_state, 42, 1, 2, -1
    ]),
    ?assertEqual(
        <<
            % lw t2,16(a2)
            16#83,
            16#23,
            16#06,
            16#01,
            % li a2,42
            16#13,
            16#06,
            16#a0,
            16#02,
            % li a3,1
            16#85,
            16#46,
            % li a4,2
            16#09,
            16#47,
            % li a5,-1
            16#fd,
            16#57,
            % jr t2
            16#82,
            16#83
        >>,
        jit_riscv32e:stream(State1)
    ).

seven_argument_tail_call_test() ->
    State0 = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    Args = [ctx, jit_state, 1, 2, 3, 4, 5],
    {RegularState, ResultReg} = jit_riscv32e:call_primitive(State0, 0, Args),
    TailState = jit_riscv32e:call_primitive_last(State0, 0, Args),
    Expected = <<
        (jit_riscv32e:stream(RegularState))/binary,
        (jit_riscv32_asm:mv(a0, ResultReg))/binary,
        (jit_riscv32_asm:ret())/binary
    >>,
    ?assertEqual(Expected, jit_riscv32e:stream(TailState)).

int64_register_tail_call_test() ->
    State0 = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    Value = 16#123456789ABCDEF0,
    TypedState = jit_riscv32e:call_primitive_last(State0, 0, [
        ctx, jit_state, 1, 2, {avm_int64_t, Value}
    ]),
    WordState = jit_riscv32e:call_primitive_last(State0, 0, [
        ctx, jit_state, 1, 2, Value band 16#FFFFFFFF, (Value bsr 32) band 16#FFFFFFFF
    ]),
    ?assertEqual(jit_riscv32e:stream(WordState), jit_riscv32e:stream(TypedState)).

split_int64_tail_call_test() ->
    State0 = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    Value = 16#123456789ABCDEF0,
    TypedState = jit_riscv32e:call_primitive_last(State0, 0, [
        ctx, jit_state, 1, 2, 3, {avm_int64_t, Value}
    ]),
    WordState = jit_riscv32e:call_primitive_last(State0, 0, [
        ctx, jit_state, 1, 2, 3, Value band 16#FFFFFFFF, (Value bsr 32) band 16#FFFFFFFF
    ]),
    ?assertEqual(jit_riscv32e:stream(WordState), jit_riscv32e:stream(TypedState)).

seven_argument_call_test() ->
    State0 = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    {State1, ResultReg} = jit_riscv32e:call_primitive(State0, 0, [
        ctx, jit_state, 1, 2, 3, 4, 5
    ]),
    ?assertEqual(t2, ResultReg),
    ?assertEqual(
        <<
            % lw t2,0(a2)
            16#83,
            16#23,
            16#06,
            16#00,
            % addi sp,sp,-16
            16#41,
            16#11,
            % sw ra,0(sp)
            16#06,
            16#c0,
            % sw a0,4(sp)
            16#2a,
            16#c2,
            % sw a1,8(sp)
            16#2e,
            16#c4,
            % sw a2,12(sp)
            16#32,
            16#c6,
            % addi sp,sp,-4
            16#71,
            16#11,
            % li t1,5
            16#15,
            16#43,
            % sw t1,0(sp)
            16#1a,
            16#c0,
            % li a2,1
            16#05,
            16#46,
            % li a3,2
            16#89,
            16#46,
            % li a4,3
            16#0d,
            16#47,
            % li a5,4
            16#91,
            16#47,
            % jalr t2
            16#82,
            16#93,
            % mv t2,a0
            16#aa,
            16#83,
            % addi sp,sp,4
            16#11,
            16#01,
            % lw ra,0(sp)
            16#82,
            16#40,
            % lw a0,4(sp)
            16#12,
            16#45,
            % lw a1,8(sp)
            16#a2,
            16#45,
            % lw a2,12(sp)
            16#32,
            16#46,
            % addi sp,sp,16
            16#41,
            16#01
        >>,
        jit_riscv32e:stream(State1)
    ).

split_int64_stack_argument_test() ->
    State0 = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    {State1, ResultReg} = jit_riscv32e:call_primitive(State0, 0, [
        ctx, jit_state, 1, 2, 3, {avm_int64_t, 16#123456789ABCDEF0}
    ]),
    ?assertEqual(t2, ResultReg),
    Stream = jit_riscv32e:stream(State1),
    % The low word occupies the last argument register, a5. The high word is
    % the first stack argument, as required by the RISC-V ILP32E ABI.
    ?assertMatch(
        <<
            _BeforeStackArg:16/binary,
            % lui t1,0x12345
            16#37,
            16#53,
            16#34,
            16#12,
            % addi t1,t1,0x678
            16#13,
            16#03,
            16#83,
            16#67,
            % sw t1,0(sp)
            16#1a,
            16#c0,
            _BeforeRegisterArg:6/binary,
            % lui a5,0x9abce
            16#b7,
            16#e7,
            16#bc,
            16#9a,
            % addi a5,a5,-0x110
            16#93,
            16#87,
            16#07,
            16#ef,
            _AfterRegisterArg/binary
        >>,
        Stream
    ).
