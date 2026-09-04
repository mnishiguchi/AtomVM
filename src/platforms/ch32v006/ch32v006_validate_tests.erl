%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_validate_tests).

-export([run/0]).

run() ->
    ok = exhaustive_compressed_encodings(),
    ok = valid_rv32ec_zmmul(),
    ok = valid_rv32c_hints(),
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

% This is intentionally separate from ch32v006_validate's decoder.  It follows
% the RV32C opcode map and operand constraints in the RISC-V Unprivileged ISA
% specification, then applies RV32E's x0-x15 register limit.  Enumerating every
% halfword detects both unsafe acceptance and accidental rejection of legal
% instructions and HINTs.
exhaustive_compressed_encodings() ->
    lists:foreach(
        fun(Instruction) ->
            Expected = rv32ec_classification(Instruction),
            Actual = validator_classification(Instruction),
            case Actual of
                Expected -> ok;
                _ -> error({compressed_classification_mismatch, Instruction, Expected, Actual})
            end
        end,
        lists:seq(0, 16#FFFF)
    ).

validator_classification(Instruction) ->
    case ch32v006_validate:validate_code(<<Instruction:16/little>>) of
        ok -> supported;
        {error, {0, _Tail, truncated_instruction}} -> longer_instruction;
        {error, {0, _Encoding, _Reason}} -> unsupported
    end.

rv32ec_classification(Instruction) ->
    Quadrant = Instruction band 3,
    Funct3 = (Instruction bsr 13) band 7,
    RdRs1 = (Instruction bsr 7) band 16#1F,
    Rs2 = (Instruction bsr 2) band 16#1F,
    Bit12 = (Instruction bsr 12) band 1,
    case {Quadrant, Funct3} of
        {3, _} ->
            longer_instruction;
        {0, 0} ->
            classify((Instruction band 16#1FE0) =/= 0);
        {0, 2} ->
            supported;
        {0, 6} ->
            supported;
        {1, 0} ->
            classify_rv32e_registers([RdRs1]);
        {1, 1} ->
            supported;
        {1, 2} ->
            classify_rv32e_registers([RdRs1]);
        {1, 3} ->
            classify_c_lui_addi16sp(Instruction, RdRs1);
        {1, 4} ->
            classify_c_arithmetic(Instruction, Bit12);
        {1, Funct3} when Funct3 >= 5 ->
            supported;
        {2, 0} ->
            classify(Bit12 =:= 0 andalso RdRs1 =< 15);
        {2, 2} ->
            classify(RdRs1 >= 1 andalso RdRs1 =< 15);
        {2, 4} ->
            classify_c_cr(Bit12, RdRs1, Rs2);
        {2, 6} ->
            classify_rv32e_registers([Rs2]);
        _ ->
            unsupported
    end.

classify_c_lui_addi16sp(Instruction, RdRs1) ->
    NonZeroImmediate = Instruction band 16#107C,
    classify(NonZeroImmediate =/= 0 andalso RdRs1 =< 15).

classify_c_arithmetic(Instruction, Bit12) ->
    Subop = (Instruction bsr 10) band 3,
    classify(
        (Subop =:= 0 andalso Bit12 =:= 0) orelse
            (Subop =:= 1 andalso Bit12 =:= 0) orelse
            Subop =:= 2 orelse
            (Subop =:= 3 andalso Bit12 =:= 0)
    ).

classify_c_cr(Bit12, RdRs1, Rs2) ->
    RegistersExist = RdRs1 =< 15 andalso Rs2 =< 15,
    Reserved = Bit12 =:= 0 andalso RdRs1 =:= 0 andalso Rs2 =:= 0,
    classify(RegistersExist andalso not Reserved).

classify_rv32e_registers(Registers) ->
    classify(lists:all(fun(Register) -> Register =< 15 end, Registers)).

classify(true) -> supported;
classify(false) -> unsupported.

valid_rv32c_hints() ->
    % c.lui x0,1; c.mv x0,a0; c.add x0,a0
    ch32v006_validate:validate_code(<<16#6005:16/little, 16#802A:16/little, 16#902A:16/little>>).

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
