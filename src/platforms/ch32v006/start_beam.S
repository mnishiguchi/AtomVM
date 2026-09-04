/*
 * This file is part of AtomVM.
 *
 * SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
 */

    .section .rodata.atomvm_start_beam, "a", @progbits
    .balign 4
    .global atomvm_start_beam
atomvm_start_beam:
    .incbin "build/start.beam"
    .global atomvm_start_beam_end
atomvm_start_beam_end:
