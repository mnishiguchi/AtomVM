/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#include <stdbool.h>
#include <stdint.h>

#define ABI_ARG_1 UINT32_C(0x11111111)
#define ABI_ARG_2 UINT32_C(0x22222222)
#define ABI_ARG_3 UINT32_C(0x33333333)
#define ABI_ARG_4 UINT32_C(0x44444444)
#define ABI_ARG_5 UINT32_C(0x55555555)
#define ABI_SPLIT_ARG UINT64_C(0x66778899AABBCCDD)
#define ABI_STACK_ARG_1 UINT32_C(0x77777777)
#define ABI_STACK_ARG_2 UINT64_C(0x8899AABBCCDDEEFF)

typedef uint32_t (*AbiCanaryEntry)(uint32_t unused_1, uint32_t unused_2, const void *interface);

extern uint32_t ch32v006_abi_canary_entry(uint32_t unused_1, uint32_t unused_2, const void *interface);

__attribute__((noinline)) static uint32_t abi_canary_target(
    uint32_t a, uint32_t b, uint32_t c, uint32_t d, uint32_t e,
    uint64_t split, uint32_t stack_1, uint64_t stack_2)
{
    uint32_t split_low = (uint32_t) split;
    uint32_t split_high = (uint32_t) (split >> 32);
    uint32_t stack_2_low = (uint32_t) stack_2;
    uint32_t stack_2_high = (uint32_t) (stack_2 >> 32);
    return a + (3U * b) + (5U * c) + (7U * d) + (11U * e)
        + (13U * split_low) + (17U * split_high) + (19U * stack_1)
        + (23U * stack_2_low) + (29U * stack_2_high);
}

bool ch32v006_run_abi_canary(void)
{
    // The generated code loads primitive slot zero. A one-entry stand-in keeps
    // the production native interface unchanged while exercising its exact
    // indirect-call sequence on the target CPU.
    const uintptr_t interface[] = { (uintptr_t) abi_canary_target };
    AbiCanaryEntry entry = ch32v006_abi_canary_entry;
    uint32_t actual = entry(0, 0, interface);
    uint32_t expected = abi_canary_target(
        ABI_ARG_1, ABI_ARG_2, ABI_ARG_3, ABI_ARG_4, ABI_ARG_5,
        ABI_SPLIT_ARG, ABI_STACK_ARG_1, ABI_STACK_ARG_2);
    return actual == expected;
}
