%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

-module(ch32v006_abi_canary_gen).

-export([generate/1]).

-include_lib("jit.hrl").

-define(VARIANT, (?JIT_VARIANT_PIC bor ?JIT_VARIANT_RV32E)).

generate(OutputFile) ->
    State0 = jit_riscv32e:new(?VARIANT, jit_stream_binary, jit_stream_binary:new(0)),
    State1 = jit_riscv32e:call_primitive_last(State0, 0, [
        16#11111111,
        16#22222222,
        16#33333333,
        16#44444444,
        16#55555555,
        {avm_int64_t, 16#66778899AABBCCDD},
        16#77777777,
        {avm_int64_t, 16#8899AABBCCDDEEFF}
    ]),
    file:write_file(OutputFile, jit_riscv32e:stream(State1)).
