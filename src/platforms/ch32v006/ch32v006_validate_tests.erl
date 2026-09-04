%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_validate_tests).

-export([run/0]).

run() ->
    ok = valid_rv32ec_zmmul(),
    ok = rv32i_only_register(),
    ok = hardware_divide(),
    ok = hardware_remainder(),
    ok = unsupported_csr(),
    ok = unsupported_r_type_encoding(),
    ok = privileged_system_instruction(),
    ok = rv64_compressed_word_operation(),
    ok = reserved_compressed_lwsp(),
    ok = reserved_compressed_addi4spn(),
    io:format("CH32V006 native-code validation tests passed~n"),
    ok.

valid_rv32ec_zmmul() ->
    Code = <<
        (jit_riscv32_asm:add(a0, a1, a2))/binary,
        (jit_riscv32_asm:mul(a0, a1, a2))/binary,
        (jit_riscv32_asm:c_nop())/binary
    >>,
    ch32v006_validate:validate_code(Code).

rv32i_only_register() ->
    % c.mv x16,a0
    {error, {0, _Instruction, {rv32e_register, 16}}} =
        ch32v006_validate:validate_code(<<16#882A:16/little>>),
    ok.

hardware_divide() ->
    Code = jit_riscv32_asm:div_(a0, a1, a2),
    {error, {0, _Instruction, hardware_divide_or_remainder}} =
        ch32v006_validate:validate_code(Code),
    ok.

hardware_remainder() ->
    Code = jit_riscv32_asm:rem_(a0, a1, a2),
    {error, {0, _Instruction, hardware_divide_or_remainder}} =
        ch32v006_validate:validate_code(Code),
    ok.

unsupported_csr() ->
    % csrrw a0,mstatus,a1
    {error, {0, _Instruction, unsupported_system_instruction}} =
        ch32v006_validate:validate_code(<<16#30059573:32/little>>),
    ok.

unsupported_r_type_encoding() ->
    % funct7=0100000 is only valid for SUB and SRA in RV32I.
    Instruction =
        (16#20 bsl 25) bor
            (12 bsl 20) bor
            (11 bsl 15) bor
            (1 bsl 12) bor
            (10 bsl 7) bor
            16#33,
    {error, {0, _Instruction, {unsupported_instruction_encoding, 16#33, 1, 16#20}}} =
        ch32v006_validate:validate_code(<<Instruction:32/little>>),
    ok.

privileged_system_instruction() ->
    % mret is not part of RV32I and must not pass as a generic SYSTEM instruction.
    {error, {0, _Instruction, unsupported_system_instruction}} =
        ch32v006_validate:validate_code(<<16#30200073:32/little>>),
    ok.

rv64_compressed_word_operation() ->
    % c.subw x8,x9 is RV64-only.
    {error, {0, _Instruction, rv64_compressed_word_operation}} =
        ch32v006_validate:validate_code(<<16#9C05:16/little>>),
    ok.

reserved_compressed_lwsp() ->
    % c.lwsp x0,0(sp) is reserved.
    {error, {0, _Instruction, reserved_compressed_lwsp}} =
        ch32v006_validate:validate_code(<<16#4002:16/little>>),
    ok.

reserved_compressed_addi4spn() ->
    % c.addi4spn with a zero immediate is reserved.
    {error, {0, _Instruction, reserved_compressed_addi4spn}} =
        ch32v006_validate:validate_code(<<0:16/little>>),
    ok.
