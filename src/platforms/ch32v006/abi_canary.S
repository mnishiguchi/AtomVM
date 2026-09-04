/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

    .section .text.ch32v006_abi_canary, "ax", @progbits
    .balign 4
    .global ch32v006_abi_canary_entry
    .type ch32v006_abi_canary_entry, @function
ch32v006_abi_canary_entry:
    .incbin "build/ch32v006_abi_canary.bin"
    .size ch32v006_abi_canary_entry, . - ch32v006_abi_canary_entry
