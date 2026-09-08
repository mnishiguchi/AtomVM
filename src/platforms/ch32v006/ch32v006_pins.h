/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#ifndef CH32V006_PINS_H
#define CH32V006_PINS_H

#include <stdbool.h>
#include <stdint.h>

#include <ch32fun.h>

static inline bool ch32v006_pin_is_safe(int32_t pin)
{
    // PC0 drives the onboard programmer's reset input on UIAPduino V1.1.
    if (pin == PC0) {
        return false;
    }
#ifndef AVM_CH32V006_ALLOW_SWIO_PIN
    // PD1 is the target's only programming/debug connection.
    if (pin == PD1) {
        return false;
    }
#endif

    int32_t port = pin >> 4;
    int32_t index = pin & 0xF;
    return index >= 0
        && ((port == 0 && index <= 7) || (port == 1 && index <= 6)
            || (port == 2 && index <= 7) || (port == 3 && index <= 7));
}

#endif
