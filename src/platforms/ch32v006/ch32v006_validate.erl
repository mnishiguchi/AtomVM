%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%
-module(ch32v006_validate).

-export([validate_beam/1, validate_beam/2, validate_code/1]).

-include_lib("jit.hrl").

-define(EXPECTED_VARIANT,
    (?JIT_VARIANT_PIC bor ?JIT_VARIANT_RV32E bor ?JIT_VARIANT_MINIMAL)
).

validate_beam(Path) ->
    validate_beam(Path, ?EXPECTED_VARIANT).

validate_beam(Path, ExpectedVariant) ->
    {ok, Beam} = file:read_file(Path),
    AvmN = find_chunk(<<"avmN">>, Beam),
    <<InfoSize:32, Info:InfoSize/binary, Code/binary>> = AvmN,
    validate_header(Info, ExpectedVariant),
    ExecutableCode = executable_code(Code),
    case validate_code(ExecutableCode) of
        ok ->
            io:format("Validated ~s: ~B bytes of rv32ec_zmmul code~n", [
                Path, byte_size(ExecutableCode)
            ]),
            ok;
        {error, Reason} ->
            error({invalid_ch32v006_native_code, Reason})
    end.

validate_header(
    <<_Labels:32, ?JIT_FORMAT_VERSION:16, 1:16, ?JIT_ARCH_RISCV32:16, ExpectedVariant:16, 0:32>>,
    ExpectedVariant
) ->
    ok;
validate_header(Info, _ExpectedVariant) ->
    error({invalid_ch32v006_native_header, Info}).

% Label zero points to the final helper function.  The bytes after its eight
% executable bytes are label/line tables, not RISC-V instructions.
executable_code(<<Auipc:32/little, Tail/binary>> = Code) ->
    16#17 = Auipc band 16#7F,
    Upper = sign_extend(Auipc band 16#FFFFF000, 32),
    Lower = jump_table_lower(Tail),
    End = Upper + Lower + 8,
    true = End >= 8 andalso End =< byte_size(Code),
    binary:part(Code, 0, End).

jump_table_lower(<<Jalr:32/little, _/binary>>) when Jalr band 3 =:= 3 ->
    16#67 = Jalr band 16#7F,
    sign_extend((Jalr bsr 20) band 16#FFF, 12);
jump_table_lower(<<CompressedJr:16/little, _/binary>>) ->
    % c.jr has no immediate.
    2 = CompressedJr band 3,
    4 = (CompressedJr bsr 13) band 7,
    0 = (CompressedJr bsr 12) band 1,
    0 = (CompressedJr bsr 2) band 16#1F,
    0.

sign_extend(Value, Bits) ->
    Sign = 1 bsl (Bits - 1),
    (Value bxor Sign) - Sign.

find_chunk(Id, <<"FOR1", _Size:32, "BEAM", Chunks/binary>>) ->
    find_chunk0(Id, Chunks).

find_chunk0(Id, <<Id:4/binary, Size:32, Data:Size/binary, _/binary>>) ->
    Data;
find_chunk0(Id, <<_OtherId:4/binary, Size:32, _Data:Size/binary, Rest0/binary>>) ->
    Padding = (4 - (Size rem 4)) rem 4,
    <<_Pad:Padding/binary, Rest/binary>> = Rest0,
    find_chunk0(Id, Rest);
find_chunk0(Id, <<>>) ->
    error({missing_beam_chunk, Id}).

validate_code(Code) ->
    validate_code(Code, 0).

validate_code(<<>>, _Offset) ->
    ok;
validate_code(<<Halfword:16/little, Rest/binary>>, Offset) when Halfword band 3 =/= 3 ->
    case validate_compressed(Halfword) of
        ok -> validate_code(Rest, Offset + 2);
        {error, Reason} -> {error, {Offset, Halfword, Reason}}
    end;
validate_code(<<Instruction:32/little, Rest/binary>>, Offset) ->
    case validate_32(Instruction) of
        ok -> validate_code(Rest, Offset + 4);
        {error, Reason} -> {error, {Offset, Instruction, Reason}}
    end;
validate_code(Tail, Offset) ->
    {error, {Offset, Tail, truncated_instruction}}.

validate_32(Instruction) ->
    Opcode = Instruction band 16#7F,
    Rd = (Instruction bsr 7) band 16#1F,
    Funct3 = (Instruction bsr 12) band 7,
    Rs1 = (Instruction bsr 15) band 16#1F,
    Rs2 = (Instruction bsr 20) band 16#1F,
    Funct7 = (Instruction bsr 25) band 16#7F,
    case Opcode of
        16#03 when
            Funct3 =:= 0;
            Funct3 =:= 1;
            Funct3 =:= 2;
            Funct3 =:= 4;
            Funct3 =:= 5
        ->
            validate_registers([Rd, Rs1]);
        16#03 ->
            unsupported_32(Opcode, Funct3, Funct7);
        16#0F ->
            validate_fence(Instruction, Rd, Funct3, Rs1, Funct7);
        16#13 when
            Funct3 =:= 0;
            Funct3 =:= 2;
            Funct3 =:= 3;
            Funct3 =:= 4;
            Funct3 =:= 6;
            Funct3 =:= 7
        ->
            validate_registers([Rd, Rs1]);
        16#13 when Funct3 =:= 1, Funct7 =:= 0 ->
            validate_registers([Rd, Rs1]);
        16#13 when
            Funct3 =:= 5, Funct7 =:= 0;
            Funct3 =:= 5, Funct7 =:= 16#20
        ->
            validate_registers([Rd, Rs1]);
        16#13 ->
            unsupported_32(Opcode, Funct3, Funct7);
        16#17 ->
            validate_registers([Rd]);
        16#23 when Funct3 =:= 0; Funct3 =:= 1; Funct3 =:= 2 ->
            validate_registers([Rs1, Rs2]);
        16#23 ->
            unsupported_32(Opcode, Funct3, Funct7);
        16#33 when Funct7 =:= 1, Funct3 >= 4 ->
            {error, hardware_divide_or_remainder};
        16#33 when Funct7 =:= 0 ->
            validate_registers([Rd, Rs1, Rs2]);
        16#33 when
            Funct7 =:= 16#20, Funct3 =:= 0;
            Funct7 =:= 16#20, Funct3 =:= 5
        ->
            validate_registers([Rd, Rs1, Rs2]);
        16#33 when Funct7 =:= 1, Funct3 =< 3 ->
            validate_registers([Rd, Rs1, Rs2]);
        16#33 ->
            unsupported_32(Opcode, Funct3, Funct7);
        16#37 ->
            validate_registers([Rd]);
        16#63 when
            Funct3 =:= 0;
            Funct3 =:= 1;
            Funct3 =:= 4;
            Funct3 =:= 5;
            Funct3 =:= 6;
            Funct3 =:= 7
        ->
            validate_registers([Rs1, Rs2]);
        16#63 ->
            unsupported_32(Opcode, Funct3, Funct7);
        16#67 when Funct3 =:= 0 ->
            validate_registers([Rd, Rs1]);
        16#67 ->
            unsupported_32(Opcode, Funct3, Funct7);
        16#6F ->
            validate_registers([Rd]);
        16#73 when Instruction =:= 16#00000073; Instruction =:= 16#00100073 ->
            ok;
        16#73 ->
            {error, unsupported_system_instruction};
        _ ->
            {error, {unsupported_opcode, Opcode}}
    end.

validate_fence(Instruction, 0, 0, 0, _Funct7) ->
    Fm = (Instruction bsr 28) band 16#F,
    case Fm of
        0 -> ok;
        _ -> {error, unsupported_fence_mode}
    end;
validate_fence(_Instruction, _Rd, Funct3, _Rs1, Funct7) ->
    unsupported_32(16#0F, Funct3, Funct7).

unsupported_32(Opcode, Funct3, Funct7) ->
    {error, {unsupported_instruction_encoding, Opcode, Funct3, Funct7}}.

validate_compressed(Instruction) ->
    Quadrant = Instruction band 3,
    Funct3 = (Instruction bsr 13) band 7,
    RdRs1 = (Instruction bsr 7) band 16#1F,
    Rs2 = (Instruction bsr 2) band 16#1F,
    Bit12 = (Instruction bsr 12) band 1,
    case {Quadrant, Funct3} of
        {0, 0} ->
            validate_c_addi4spn(Instruction);
        {0, 2} ->
            ok;
        {0, 6} ->
            ok;
        {1, 0} ->
            validate_registers([RdRs1]);
        {1, 1} ->
            ok;
        {1, 2} ->
            validate_registers([RdRs1]);
        {1, 3} ->
            validate_c_lui_addi16sp(Instruction, RdRs1);
        {1, 4} ->
            validate_c_arithmetic(Instruction, Bit12);
        {1, 5} ->
            ok;
        {1, 6} ->
            ok;
        {1, 7} ->
            ok;
        {2, 0} when Bit12 =:= 0 ->
            validate_registers([RdRs1]);
        {2, 0} ->
            {error, rv64_compressed_shift};
        {2, 2} when RdRs1 =/= 0 ->
            validate_registers([RdRs1]);
        {2, 2} ->
            {error, reserved_compressed_lwsp};
        {2, 4} ->
            validate_c_cr(Bit12, RdRs1, Rs2);
        {2, 6} ->
            validate_registers([Rs2]);
        _ ->
            {error, {unsupported_compressed_instruction, Quadrant, Funct3}}
    end.

validate_c_addi4spn(Instruction) ->
    case Instruction band 16#1FE0 of
        0 -> {error, reserved_compressed_addi4spn};
        _ -> ok
    end.

validate_c_lui_addi16sp(Instruction, RdRs1) ->
    Immediate = Instruction band 16#107C,
    case {Immediate, RdRs1} of
        {0, _} -> {error, reserved_compressed_lui};
        {_, 0} -> ok;
        _ -> validate_registers([RdRs1])
    end.

validate_c_arithmetic(Instruction, Bit12) ->
    Subop = (Instruction bsr 10) band 3,
    case {Subop, Bit12} of
        {0, 0} -> ok;
        {1, 0} -> ok;
        {2, _} -> ok;
        {3, 0} -> ok;
        {0, 1} -> {error, rv64_compressed_shift};
        {1, 1} -> {error, rv64_compressed_shift};
        {3, 1} -> {error, rv64_compressed_word_operation}
    end.

validate_c_cr(Bit12, RdRs1, Rs2) ->
    case {Bit12, RdRs1, Rs2} of
        {0, 0, 0} ->
            {error, reserved_compressed_cr};
        {0, _, _} ->
            validate_registers([RdRs1, Rs2]);
        {1, 0, 0} ->
            ok;
        {1, _, _} ->
            validate_registers([RdRs1, Rs2])
    end.

validate_registers(Registers) ->
    case lists:dropwhile(fun(Register) -> Register =< 15 end, Registers) of
        [] -> ok;
        [Register | _] -> {error, {rv32e_register, Register}}
    end.
