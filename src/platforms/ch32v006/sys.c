/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#include <ch32fun.h>

#include "ch32v006_time.h"

#include <defaultatoms.h>
#include <sys.h>
#include <utils.h>

/* Track complete milliseconds so the hot path avoids 64-bit tick division on RV32E. */
#define SYSTICK_MAX_DELAY_MS ((UINT32_MAX / DELAY_MS_TIME) / 2U)
#if defined(AVM_CH32V006_SELF_TEST) && !defined(AVM_CH32V006_PRODUCTION_TIME_SOAK_SELF_TEST)
#define SYSTICK_TRACK_INTERVAL_MS 10U
#else
#define SYSTICK_TRACK_INTERVAL_MS SYSTICK_MAX_DELAY_MS
#endif
#define SYSTICK_TRACK_INTERVAL_TICKS (DELAY_MS_TIME * SYSTICK_TRACK_INTERVAL_MS)

static volatile uint32_t systick_sequence;
static volatile uint32_t systick_completed_intervals;
static volatile uint32_t systick_interval_start;
#ifdef AVM_CH32V006_SYSTICK_WRAP_SELF_TEST
static uint32_t systick_wrap_test_start;
static bool systick_wrap_test_prepared;
#endif

void platform_stack_guard_check(void);

void ch32v006_time_init(void)
{
    uint32_t now = funSysTick32();
    systick_sequence = 0;
    systick_completed_intervals = 0;
    systick_interval_start = now;
    SysTick->CMP = now + SYSTICK_TRACK_INTERVAL_TICKS;
    SysTick->SR = 0;
    SysTick->CTLR |= SYSTICK_CTLR_STIE;
    NVIC_EnableIRQ(SysTick_IRQn);
}

void SysTick_Handler(void) __attribute__((interrupt));
void SysTick_Handler(void)
{
    ++systick_sequence;
    systick_interval_start += SYSTICK_TRACK_INTERVAL_TICKS;
    ++systick_completed_intervals;
    SysTick->CMP += SYSTICK_TRACK_INTERVAL_TICKS;
    SysTick->SR = 0;
    ++systick_sequence;
}

void platform_defaultatoms_init(GlobalContext *global)
{
    UNUSED(global);
}

void sys_init_platform(GlobalContext *global)
{
    global->platform_data = NULL;
}

void sys_free_platform(GlobalContext *global)
{
    UNUSED(global);
}

void ch32v006_delay_ms(uint32_t milliseconds)
{
    platform_stack_guard_check();
    while (milliseconds > 0) {
        uint32_t delay_milliseconds = SYSTICK_MAX_DELAY_MS;
        if (milliseconds < delay_milliseconds) {
            delay_milliseconds = milliseconds;
        }

        Delay_Ms(delay_milliseconds);
        milliseconds -= delay_milliseconds;
    }
    platform_stack_guard_check();
}

void sys_poll_events(GlobalContext *global, int timeout_ms)
{
    UNUSED(global);
    if (timeout_ms > 0) {
        ch32v006_delay_ms((uint32_t) timeout_ms);
    }
}

void sys_register_select_event(GlobalContext *global, ErlNifEvent event, bool is_write)
{
    UNUSED(global);
    UNUSED(event);
    UNUSED(is_write);
}

void sys_unregister_select_event(GlobalContext *global, ErlNifEvent event, bool is_write)
{
    UNUSED(global);
    UNUSED(event);
    UNUSED(is_write);
}

void sys_listener_destroy(struct ListHead *item)
{
    UNUSED(item);
}

enum OpenAVMResult sys_open_avm_from_file(GlobalContext *global, const char *path, struct AVMPackData **data)
{
    UNUSED(global);
    UNUSED(path);
    UNUSED(data);
    return AVM_OPEN_NOT_SUPPORTED;
}

Module *sys_load_module_from_file(GlobalContext *global, const char *path)
{
    UNUSED(global);
    UNUSED(path);
    return NULL;
}

Context *sys_create_port(GlobalContext *global, const char *driver_name, term opts)
{
    UNUSED(global);
    UNUSED(driver_name);
    UNUSED(opts);
    return NULL;
}

term sys_get_info(Context *ctx, term key)
{
    UNUSED(ctx);
    UNUSED(key);
    return UNDEFINED_ATOM;
}

void sys_time(struct timespec *t)
{
    sys_monotonic_time(t);
}

void sys_monotonic_time(struct timespec *t)
{
    uint64_t now = sys_monotonic_time_u64();
    t->tv_sec = (time_t) (now / 1000);
    t->tv_nsec = (long) ((now % 1000) * 1000000);
}

uint64_t sys_monotonic_time_u64(void)
{
    uint32_t sequence_before;
    uint32_t completed_intervals;
    uint32_t interval_start;
    uint32_t systick;
    uint32_t sequence_after;
    do {
        sequence_before = systick_sequence;
        completed_intervals = systick_completed_intervals;
        interval_start = systick_interval_start;
        systick = funSysTick32();
        sequence_after = systick_sequence;
    } while ((sequence_before & 1U) || sequence_before != sequence_after);

    uint64_t completed_milliseconds = (uint64_t) completed_intervals * SYSTICK_TRACK_INTERVAL_MS;
    uint32_t elapsed_milliseconds = (uint32_t) (systick - interval_start) / DELAY_MS_TIME;
    return completed_milliseconds + elapsed_milliseconds;
}

#ifdef AVM_CH32V006_SYSTICK_WRAP_SELF_TEST
void ch32v006_time_prepare_wrap_test(void)
{
    const uint32_t start = UINT32_MAX - (30U * DELAY_MS_TIME);
    const bool interrupts_enabled = __isenabled_irq();

    __disable_irq();
    const uint32_t control = SysTick->CTLR;
    SysTick->CTLR = control & ~(SYSTICK_CTLR_STE | SYSTICK_CTLR_STIE);
    systick_sequence = 1;
    systick_completed_intervals = 0;
    systick_interval_start = start;
    systick_wrap_test_start = start;
    systick_wrap_test_prepared = true;
    SysTick->CNT = start;
    SysTick->CMP = start + SYSTICK_TRACK_INTERVAL_TICKS;
    SysTick->SR = 0;
    systick_sequence = 2;
    SysTick->CTLR = control;
    if (interrupts_enabled) {
        __enable_irq();
    }
}

bool ch32v006_time_wrap_test_passed(void)
{
    return systick_wrap_test_prepared && funSysTick32() < systick_wrap_test_start
        && sys_monotonic_time_u64() >= 40U;
}
#endif

#ifdef AVM_CH32V006_PRODUCTION_TIME_SOAK_SELF_TEST
bool ch32v006_time_production_soak_passed(void)
{
    const uint64_t two_wraps_ms
        = ((UINT64_C(1) << 33) + DELAY_MS_TIME - 1U) / DELAY_MS_TIME;
    return systick_completed_intervals >= 4U && sys_monotonic_time_u64() >= two_wraps_ms;
}
#endif

#ifdef AVM_CH32V006_SELF_TEST
bool ch32v006_time_self_test(void)
{
    uint64_t before = sys_monotonic_time_u64();
    ch32v006_delay_ms(25);
    return sys_monotonic_time_u64() - before >= 20;
}
#endif

uint64_t sys_monotonic_time_ms_to_u64(uint64_t ms)
{
    return ms;
}

uint64_t sys_monotonic_time_u64_to_ms(uint64_t value)
{
    return value;
}

#ifndef AVM_NO_JIT
ModuleNativeEntryPoint sys_map_native_code(const uint8_t *code, size_t code_size)
{
    UNUSED(code_size);
    return (ModuleNativeEntryPoint) code;
}

void sys_release_native_code(ModuleNativeEntryPoint entry_point)
{
    // Native code is embedded in flash; there is no mapping to release.
    UNUSED(entry_point);
}

bool sys_get_cache_native_code(GlobalContext *global, Module *module, uint16_t *version, ModuleNativeEntryPoint *entry_point, uint32_t *labels)
{
    UNUSED(global);
    UNUSED(module);
    UNUSED(version);
    UNUSED(entry_point);
    UNUSED(labels);
    return false;
}

void sys_set_cache_native_code(GlobalContext *global, Module *module, uint16_t version, ModuleNativeEntryPoint entry_point, uint32_t labels)
{
    UNUSED(global);
    UNUSED(module);
    UNUSED(version);
    UNUSED(entry_point);
    UNUSED(labels);
}
#endif
