/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#include <stdbool.h>
#include <stdint.h>
#ifdef AVM_CH32V006_SELF_TEST
#include <stdio.h>
#endif
#include <string.h>

#include <ch32fun.h>

#include "ch32v006_time.h"

#include <defaultatoms.h>
#include <interop.h>
#ifdef AVM_CH32V006_SELF_TEST
#include <memory.h>
#endif
#include <platform_nifs.h>
#include <term.h>

#ifdef AVM_CH32V006_SELF_TEST
void platform_heap_stats(size_t *capacity, size_t *current, size_t *peak);
size_t platform_stack_peak(void);
size_t platform_stack_reserve(void);
#endif

enum
{
    GPIOPinModeInput,
    GPIOPinModeOutput,
    GPIOPinModeOutputOpenDrain
};

static const AtomStringIntPair pin_mode_table[] = {
    { ATOM_STR("\x5", "input"), GPIOPinModeInput },
    { ATOM_STR("\x6", "output"), GPIOPinModeOutput },
    { ATOM_STR("\x9", "output_od"), GPIOPinModeOutputOpenDrain },
    SELECT_INT_DEFAULT(-1)
};

enum
{
    GPIOPullFloating,
    GPIOPullUp,
    GPIOPullDown
};

static const AtomStringIntPair pull_mode_table[] = {
    { ATOM_STR("\x2", "up"), GPIOPullUp },
    { ATOM_STR("\x4", "down"), GPIOPullDown },
    { ATOM_STR("\x8", "floating"), GPIOPullFloating },
    SELECT_INT_DEFAULT(-1)
};

static const AtomStringIntPair pin_level_table[] = {
    { ATOM_STR("\x3", "low"), FUN_LOW },
    { ATOM_STR("\x4", "high"), FUN_HIGH },
    SELECT_INT_DEFAULT(-1)
};

static bool pin_is_safe(int32_t pin)
{
    // PC0 drives the onboard programmer's reset input on UIAPduino V1.1.
    if (pin == PC0) {
        return false;
    }

    int32_t port = pin >> 4;
    int32_t index = pin & 0xF;
    return index >= 0 && ((port == 0 && index <= 7) || (port == 1 && index <= 6) || (port == 2 && index <= 7) || (port == 3 && index <= 7));
}

static bool get_pin(term pin_term, int32_t *pin)
{
    if (!term_is_integer(pin_term)) {
        return false;
    }
    *pin = term_to_int32(pin_term);
    return pin_is_safe(*pin);
}

static term nif_atomvm_platform(Context *ctx, int argc, term argv[])
{
    UNUSED(argc);
    UNUSED(argv);
    return globalcontext_make_atom(ctx->global, ATOM_STR("\x8", "ch32v006"));
}

static term nif_gpio_init(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    int32_t pin;
    if (argc != 1 || !get_pin(argv[0], &pin)) {
        return term_invalid_term();
    }
    UNUSED(pin);
    return OK_ATOM;
}

static term nif_gpio_deinit(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    int32_t pin;
    if (argc != 1 || !get_pin(argv[0], &pin)) {
        return term_invalid_term();
    }
    funPinMode((uint32_t) pin, FUN_INPUT);
    return OK_ATOM;
}

static term nif_gpio_set_pin_mode(Context *ctx, int argc, term argv[])
{
    int32_t pin;
    if (argc != 2 || !get_pin(argv[0], &pin)) {
        return term_invalid_term();
    }

    int mode = interop_atom_term_select_int(pin_mode_table, argv[1], ctx->global);
    switch (mode) {
        case GPIOPinModeInput:
            funPinMode((uint32_t) pin, FUN_INPUT);
            break;
        case GPIOPinModeOutput:
            funPinMode((uint32_t) pin, FUN_OUTPUT);
            break;
        case GPIOPinModeOutputOpenDrain:
            funPinMode((uint32_t) pin, GPIO_Speed_10MHz | GPIO_CNF_OUT_OD);
            break;
        default:
            return term_invalid_term();
    }
    return OK_ATOM;
}

static term nif_gpio_set_pin_pull(Context *ctx, int argc, term argv[])
{
    int32_t pin;
    if (argc != 2 || !get_pin(argv[0], &pin)) {
        return term_invalid_term();
    }

    int pull = interop_atom_term_select_int(pull_mode_table, argv[1], ctx->global);
    switch (pull) {
        case GPIOPullFloating:
            funPinMode((uint32_t) pin, FUN_INPUT);
            break;
        case GPIOPullUp:
        case GPIOPullDown:
            funPinMode((uint32_t) pin, GPIO_CNF_IN_PUPD);
            funDigitalWrite((uint32_t) pin, pull == GPIOPullUp ? FUN_HIGH : FUN_LOW);
            break;
        default:
            return term_invalid_term();
    }
    return OK_ATOM;
}

static term nif_gpio_digital_write(Context *ctx, int argc, term argv[])
{
    int32_t pin;
    if (argc != 2 || !get_pin(argv[0], &pin)) {
        return term_invalid_term();
    }

    int level;
    if (term_is_integer(argv[1])) {
        level = term_to_int32(argv[1]);
    } else {
        level = interop_atom_term_select_int(pin_level_table, argv[1], ctx->global);
    }
    if (level != FUN_LOW && level != FUN_HIGH) {
        return term_invalid_term();
    }

    funDigitalWrite((uint32_t) pin, level);
    return OK_ATOM;
}

static term nif_gpio_digital_read(Context *ctx, int argc, term argv[])
{
    int32_t pin;
    if (argc != 1 || !get_pin(argv[0], &pin)) {
        return term_invalid_term();
    }

    return funDigitalRead((uint32_t) pin)
        ? globalcontext_make_atom(ctx->global, ATOM_STR("\x4", "high"))
        : globalcontext_make_atom(ctx->global, ATOM_STR("\x3", "low"));
}

static term nif_delay_ms(Context *ctx, int argc, term argv[])
{
    UNUSED(ctx);
    if (argc != 1 || !term_is_integer(argv[0])) {
        return term_invalid_term();
    }

    avm_int_t milliseconds = term_to_int(argv[0]);
    if (milliseconds < 0) {
        return term_invalid_term();
    }

    ch32v006_delay_ms((uint32_t) milliseconds);
    return OK_ATOM;
}

#ifdef AVM_CH32V006_SELF_TEST
static term nif_report(Context *ctx, int argc, term argv[])
{
    if (argc != 1) {
        return term_invalid_term();
    }

    term passed = globalcontext_make_atom(ctx->global, ATOM_STR("\x6", "passed"));
    term failed = globalcontext_make_atom(ctx->global, ATOM_STR("\x6", "failed"));
    bool success = argv[0] == passed;
    if (success) {
        printf("AtomVM self-test: passed\n");
    } else if (argv[0] == failed) {
        printf("AtomVM self-test: failed\n");
    } else {
        return term_invalid_term();
    }
    size_t capacity;
    size_t current;
    size_t peak;
    platform_heap_stats(&capacity, &current, &peak);
    printf("AtomVM heap: %lu/%lu bytes, peak %lu\n", (unsigned long) current,
        (unsigned long) capacity, (unsigned long) peak);
    printf("AtomVM process heap: %lu words, %lu free\n",
        (unsigned long) memory_heap_memory_size(&ctx->heap),
        (unsigned long) context_avail_free_memory(ctx));
    printf("AtomVM C stack peak: %lu/%lu bytes\n", (unsigned long) platform_stack_peak(),
        (unsigned long) platform_stack_reserve());
    return success ? OK_ATOM : term_invalid_term();
}
#endif

#define DEFINE_NIF(name)                                          \
    static const struct Nif name##_nif                            \
        __attribute__((section(".rodata.ch32v006_nifs")))         \
        = {                                                       \
              .base.type = NIFFunctionType, .nif_ptr = nif_##name \
          }

DEFINE_NIF(atomvm_platform);
DEFINE_NIF(gpio_init);
DEFINE_NIF(gpio_deinit);
DEFINE_NIF(gpio_set_pin_mode);
DEFINE_NIF(gpio_set_pin_pull);
DEFINE_NIF(gpio_digital_write);
DEFINE_NIF(gpio_digital_read);
DEFINE_NIF(delay_ms);
#ifdef AVM_CH32V006_SELF_TEST
DEFINE_NIF(report);
#endif

const struct Nif *platform_nifs_get_nif(const char *nifname)
{
    if (strcmp("atomvm:platform/0", nifname) == 0) {
        return &atomvm_platform_nif;
    }
    if (strcmp("gpio:init/1", nifname) == 0 || strcmp("Elixir.GPIO:init/1", nifname) == 0) {
        return &gpio_init_nif;
    }
    if (strcmp("gpio:deinit/1", nifname) == 0 || strcmp("Elixir.GPIO:deinit/1", nifname) == 0) {
        return &gpio_deinit_nif;
    }
    if (strcmp("gpio:set_pin_mode/2", nifname) == 0 || strcmp("Elixir.GPIO:set_pin_mode/2", nifname) == 0) {
        return &gpio_set_pin_mode_nif;
    }
    if (strcmp("gpio:set_pin_pull/2", nifname) == 0 || strcmp("Elixir.GPIO:set_pin_pull/2", nifname) == 0) {
        return &gpio_set_pin_pull_nif;
    }
    if (strcmp("gpio:digital_write/2", nifname) == 0 || strcmp("Elixir.GPIO:digital_write/2", nifname) == 0) {
        return &gpio_digital_write_nif;
    }
    if (strcmp("gpio:digital_read/1", nifname) == 0 || strcmp("Elixir.GPIO:digital_read/1", nifname) == 0) {
        return &gpio_digital_read_nif;
    }
    if (strcmp("ch32v006:delay_ms/1", nifname) == 0) {
        return &delay_ms_nif;
    }
#ifdef AVM_CH32V006_SELF_TEST
    if (strcmp("ch32v006:report/1", nifname) == 0) {
        return &report_nif;
    }
#endif
    return NULL;
}
