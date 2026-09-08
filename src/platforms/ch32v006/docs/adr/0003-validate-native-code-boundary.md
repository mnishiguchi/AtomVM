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
outside the default native interface. The optional byte-binary tier described
in [ADR 0004](0004-explicit-capability-tiers.md) exposes only its selected helpers.
The build then decodes the generated instruction stream and rejects registers
or instructions outside `rv32ec_zmmul`.

## Consequences

A regular RV32E image cannot load on the constrained runtime. Unsupported BEAM
operations and literals covered by the AOT boundary fail while building the
firmware. This is not a guarantee that every external import is resolved:
unresolved external calls, including unselected peripheral NIFs, raise catchable
`undef` at runtime. Every platform image, including user-supplied Elixir BEAM
files, passes through the same machine-code validator, and CI exercises
representative positive and negative images.

Acceptance must cover the generated execution path as well as source-level
behavior. Compilers can express the same operation as a BEAM opcode or an
external BIF/NIF call. When adding such an adapter, verify which path the test
uses and exercise its argument errors and allocation-failure recovery where
applicable; an opcode test does not qualify the adapter.

The host validator tests enumerate all 65,536 halfword encodings against a
separate RV32EC classification. This covers the compressed-instruction decoder;
it does not replace generated-code ABI tests or physical-board execution.
