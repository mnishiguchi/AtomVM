/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#include <stdio.h>

#include <ch32fun.h>

#include <globalcontext.h>
#include <module.h>

#include "ch32v006_time.h"

#define LED_BUILTIN PC3

extern const uint8_t atomvm_start_beam[];
extern const uint8_t atomvm_start_beam_end[];
void platform_stack_guard_init(void);
bool platform_stack_guard_ok(void);
#ifdef AVM_CH32V006_SELF_TEST
bool ch32v006_run_abi_canary(void);
void platform_stack_probe_start(void);
#endif
#ifdef AVM_CH32V006_ALLOCATOR_FAULT_INJECTION
void platform_allocator_fail_next(void);
#endif

static void result_led_init(void)
{
    // PWM uses PC3 as TIM1 channel 3, so restore GPIO mode before reporting.
    funPinMode(LED_BUILTIN, FUN_OUTPUT);
}

static void show_result(bool success)
{
    result_led_init();
    while (1) {
        funDigitalWrite(LED_BUILTIN, FUN_HIGH);
        Delay_Ms(success ? 100 : 600);
        funDigitalWrite(LED_BUILTIN, FUN_LOW);
        Delay_Ms(success ? 900 : 400);
    }
}

int main(void)
{
    SystemInit();
    funGpioInitAll();
    result_led_init();
    platform_stack_guard_init();
    ch32v006_time_init();

#ifdef AVM_CH32V006_SELF_TEST
    platform_stack_probe_start();
#endif

    printf("AVM CH32V006 boot\n");
#ifdef AVM_CH32V006_SELF_TEST
    if (!ch32v006_time_self_test()) {
        printf("FAIL SysTick time\n");
        show_result(false);
    }
    printf("SysTick time ok\n");
    if (!ch32v006_run_abi_canary()) {
        printf("FAIL RV32E ABI\n");
        show_result(false);
    }
    printf("RV32E ABI ok\n");
#endif

    GlobalContext *global = globalcontext_new();
    if (!global) {
        printf("FAIL globalcontext_new\n");
        show_result(false);
    }
    size_t beam_size = (size_t) (atomvm_start_beam_end - atomvm_start_beam);
    Module *module = module_new_from_iff_binary(global, atomvm_start_beam, beam_size);
    if (!module || globalcontext_insert_module(global, module) < 0) {
        printf("FAIL module load\n");
        show_result(false);
    }

    run_result_t result;
#ifdef AVM_CH32V006_OOM_SELF_TEST
    platform_allocator_fail_next();
    result = globalcontext_run(global, module, NULL, 0, NULL);
    bool success = result == RUN_MEMORY_FAILURE && platform_stack_guard_ok();
    printf("AtomVM initial-process OOM: %s\n", success ? "passed" : "failed");
#else
    result = globalcontext_run(global, module, NULL, 0, NULL);
    bool success = result == RUN_SUCCESS && platform_stack_guard_ok();
#endif
    if (!platform_stack_guard_ok()) {
        printf("FAIL C stack guard\n");
    }
    printf("%s\n", success ? "ok" : "error");
    show_result(success);
}
