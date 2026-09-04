# ADR 0003: Validate the constrained native-code boundary

**Status:** Accepted

## Context

RV32E ELF metadata does not prove that generated application code avoids
x16-x31 or instructions absent from `rv32ec_zmmul`. The CH32V006 runtime also
links only part of AtomVM's native interface, so an otherwise valid RV32E image
could call a missing function pointer.

## Decision

Mark constrained images and runtimes with the `minimal` native-code variant.
During AOT generation, reject missing native helpers, unsupported direct BIFs,
dynamic apply, and unsupported literal types. Opaque binary literals remain
loadable because Elixir emits one for module metadata; binary operations stay
outside the native interface. The build then decodes the generated instruction
stream and rejects registers or instructions outside `rv32ec_zmmul`.

## Consequences

A regular RV32E image cannot load on the constrained runtime. Unsupported BEAM
features fail while building the firmware, before they reach hardware. Every
platform image, including user-supplied Elixir BEAM files, passes through the
same machine-code validator, and CI exercises representative positive and
negative images.
