---
name: healthkit-code-review
description: Reviews HealthKit code for authorization patterns, query usage, query descriptors, background delivery, and data type handling. Use when reviewing code with import HealthKit, HKHealthStore, HKSampleQuery, HKSampleQueryDescriptor, HKObserverQuery, or HKQuantityType.
---

# HealthKit Code Review

## Quick Reference

| Issue Type | Reference |
|------------|-----------|
| HKHealthStore, permissions, status checks, privacy | [references/authorization.md](references/authorization.md) |
| Query descriptors, HKQuery types, predicates, anchored queries, statistics | [references/queries.md](references/queries.md) |
| Background delivery, observer queries, SwiftUI/watchOS app lifecycle | [references/background.md](references/background.md) |
| HKQuantityType, HKCategoryType, workouts, units | [references/data-types.md](references/data-types.md) |

## Review Checklist

- [ ] `HKHealthStore.isHealthDataAvailable()` called before any HealthKit operations
- [ ] Authorization requested only for needed data types (minimal permissions)
- [ ] `requestAuthorization` completion/return not misinterpreted as read permission granted
- [ ] No attempt to determine read permission status (privacy by design)
- [ ] UI updates isolated on `@MainActor` (or dispatched to main actor from legacy query callbacks)
- [ ] `HKObjectQueryNoLimit` / unbounded descriptors used only with bounded predicates
- [ ] `HKStatisticsQueryDescriptor` / `HKStatisticsQuery` used for aggregations instead of manual summing
- [ ] Observer query `completionHandler()` always called (use `defer`)
- [ ] Background delivery registered every launch (`App.init()` / `application(_:didFinishLaunchingWithOptions:)` / `WKApplicationDelegate.applicationDidFinishLaunching()`)
- [ ] Background delivery entitlement (`com.apple.developer.healthkit.background-delivery`) added (iOS 15+)
- [ ] Correct units used for quantity types (e.g., `count/min` for heart rate)
- [ ] Long-running queries / `results(for:)` `Task`s stored and cancelled/`stop()`ped on teardown

## When to Load References

- Reviewing authorization/permissions flow -> authorization.md
- Reviewing `HKSampleQueryDescriptor`, `HKAnchoredObjectQueryDescriptor`, `HKSampleQuery`, or predicates -> queries.md
- Reviewing `HKObserverQuery` or `enableBackgroundDelivery` -> background.md
- Reviewing `HKQuantityType`, `HKCategoryType`, or `HKWorkoutBuilder` -> data-types.md

## Review gates

Run in order. **Do not state a finding in a later step until the pass condition for the current step is satisfied** (each pass condition is answerable from the codebase under review).

1. **Scope** — **Pass:** Name the file path(s) and types/symbols using `HealthKit`, `HKHealthStore`, or `HK*` APIs (or state clearly that the diff touches none).
2. **Availability and store** — **Pass:** Cite the call site of `isHealthDataAvailable()` before HealthKit use, or document why omission is acceptable for the scoped code; cite where `HKHealthStore` is created or injected.
3. **Authorization semantics** — **Pass:** For each `requestAuthorization` / `statusForAuthorizationRequest` / `getRequestStatusForAuthorization`, cite handler branches per [references/authorization.md](references/authorization.md) (e.g., success does not prove read access); do not infer read permission from `authorizationStatus` alone.
4. **Queries and limits** — **Pass:** For each query or descriptor, cite predicate + limit (`HKObjectQueryNoLimit` only with a bounded predicate); for totals/aggregates, cite `HKStatisticsQueryDescriptor` / `HKStatisticsQuery` vs manual summing per [references/queries.md](references/queries.md).
5. **Observers and background** — **Pass:** If `HKObserverQuery` or `enableBackgroundDelivery` appears, cite where the observer is started/stopped and where background delivery is registered on launch; cite entitlements/`Info.plist` or flag missing config per [references/background.md](references/background.md). If absent, **Pass:** one line “no observer/background in scope.”
6. **Threading, lifecycle, and protocol** — **Pass:** Cite `@MainActor` isolation (or main-queue dispatch) for UI updates; cite retention/`stop()`/`Task.cancel()` for long-running queries; satisfy `review-verification-protocol` ([../review-verification-protocol/SKILL.md](../review-verification-protocol/SKILL.md) if installed).

## Review Questions

1. Is `isHealthDataAvailable()` checked before creating or using `HKHealthStore`?
2. Does the code gracefully handle denied read permissions (empty results)?
3. Are observer query completion handlers called in all code paths?
4. Is work in background handlers minimal (~15 second limit)?
5. Are `HKQueryAnchor`s persisted separately per sample type?
