# CH32V006 architecture decisions

These records capture durable platform decisions. Build and usage instructions
remain in the [platform README](../../README.md); implementation detail belongs
in [design.md](../design.md). The [roadmap](../roadmap.md) sets priorities;
[qualification records](../qualification.md) hold test evidence.

- [ADR 0001: Use RV32E AOT and a single native image](0001-rv32e-aot-native-image.md)
- [ADR 0002: Define the constrained runtime and memory boundary](0002-constrained-runtime-memory-boundary.md)
- [ADR 0003: Validate the constrained native-code boundary](0003-validate-native-code-boundary.md)
- [ADR 0004: Add capabilities as explicit build-time tiers](0004-explicit-capability-tiers.md)
- [ADR 0005: Qualify configurations with reproducible evidence](0005-evidence-based-qualification.md)
- [ADR 0006: Promote the two-process timer profile](0006-promote-two-process-timer-profile.md)

Add an ADR when changing the firmware model, runtime boundary, capability ABI,
or qualification policy. Record context, decision, and consequences; keep exact
API lists and measurements in their owning documents. Clarify existing records
when needed, but use a linked new ADR to supersede a decision so its rationale
remains available. Routine fixes and test runs do not need an ADR.
