# ADR 0005: Qualify configurations with reproducible evidence

**Status:** Accepted

**Date:** 2026-09-07

## Context

The basic runtime and peripheral implementations exist. Several optional
runtime workloads pass on hardware, while peripheral evidence ranges from
host builds to smoke tests. Passing a small test neither establishes electrical
correctness nor proves that a larger application fits. Some images barely
exceed the flash-headroom policy, and measured C-stack margins vary by workload.

## Decision

Extend [ADR 0004](0004-explicit-capability-tiers.md) with explicit qualification
gates for a named configuration, not an entire feature family:

1. Document the selected runtime/driver features, supported operations, limits,
   and failure behavior. Preserve deterministic AOT rejection and variant
   checks; document catchable runtime errors such as unresolved-import `undef`.
2. Pass the relevant host regression, negative AOT, instruction, ABI, and image
   checks. Retain at least 1,024 flash bytes of headroom unless an experiment
   explicitly overrides the policy; such an override is not promotion evidence.
3. Run the exact image on the board with the required wiring. Test functional
   behavior, relevant electrical properties, failure recovery, and sustained
   execution. A smoke test qualifies only the behavior it observes.
4. Measure allocator usage and C-stack high-water under representative load and
   memory pressure. Keep the production canary. Justify margins for the
   workload; there is no universal safe stack margin inferred from one run.
5. Record the build identity and results in
   [qualification records](../qualification.md), then explicitly review
   promotion and update the supported contract.

Qualify combined configurations separately. Stable optional capabilities need
not enter the default image. New features require a concrete application need
and measured resource cost before broadening the runtime boundary.

Record how acceptance instrumentation changes the production configuration,
including timing intervals, stack reserve, and allocation-failure hooks. Use
accelerated tests for targeted regressions and production settings for claims
about sustained production behavior. Define the duration or cycle count,
completion condition, and external timeout before a long-running test.

Flash headroom is a build gate, not an application-capacity guarantee. Compare
size changes using the same application, build options, and toolchain; report
both remaining flash and margin above the gate. Heap and stack measurements
must retain their workload and instrumentation context.

## Consequences

Host builds, board smoke tests, workload acceptance, and stable support remain
distinct claims. Changes to relevant code, feature options, toolchains, or
dependencies require renewed affected qualification; earlier results remain
historical evidence.

The roadmap holds priorities and completion criteria. Qualification records
hold measurements and reproducibility details. ADRs hold durable decisions;
routine test runs and size changes do not need new ADRs.
