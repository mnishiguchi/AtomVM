%
% This file is part of AtomVM.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

%% The RV32E backend shares instruction selection with RV32 while restricting
%% allocation and ABI argument registers to x0-x15.
-define(JIT_RISCV32E, true).
-include("jit_riscv32.erl").
