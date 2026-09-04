# ADR 0001: Use RV32E AOT and a single native image

**Status:** Accepted

## Context

CH32V006 provides 63,488 usable flash bytes, 8 KiB SRAM, and an RV32E core.
The regular AtomVM interpreter does not fit this flash budget. RV32E also uses
the ILP32E ABI: six argument registers, three temporary registers, and
4-byte stack alignment.

## Decision

Precompile the startup BEAM with AtomVM's `riscv32e` AOT target and embed it
directly in the firmware. The native chunk carries an RV32E variant bit, so an
ordinary RV32 native chunk is rejected. The backend follows ILP32E register,
stack-argument, and stack-alignment rules.

## Consequences

Each firmware image contains AtomVM and one startup module. There is no
interpreter, application partition, dynamic module loading, or AVM archive
loading. Updating an application rebuilds and reflashes the complete image.

The generated ABI path is qualified by host tests and a physical-board C ABI
canary that covers stack arguments and 64-bit argument splitting.
