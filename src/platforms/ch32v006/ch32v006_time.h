/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#ifndef CH32V006_TIME_H
#define CH32V006_TIME_H

#include <stdbool.h>
#include <stdint.h>

void ch32v006_time_init(void);
void ch32v006_delay_ms(uint32_t milliseconds);
#ifdef AVM_CH32V006_SELF_TEST
bool ch32v006_time_self_test(void);
#endif
#ifdef AVM_CH32V006_SYSTICK_WRAP_SELF_TEST
void ch32v006_time_prepare_wrap_test(void);
bool ch32v006_time_wrap_test_passed(void);
#endif
#ifdef AVM_CH32V006_PRODUCTION_TIME_SOAK_SELF_TEST
bool ch32v006_time_production_soak_passed(void);
#endif

#endif
