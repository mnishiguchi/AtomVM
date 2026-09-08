/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

#ifndef CH32V006_PERIPHERALS_H
#define CH32V006_PERIPHERALS_H

struct Nif;

const struct Nif *ch32v006_peripherals_get_nif(const char *nifname);

#endif
