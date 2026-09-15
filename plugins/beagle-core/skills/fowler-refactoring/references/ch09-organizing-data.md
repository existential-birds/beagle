# Chapter 9 — Organizing Data

Source: Fowler, Second Edition, Chapter 9, PDF pp. 268–288.
Central distinctions: separate responsibilities, authoritative versus derived state, and identity versus value.

## Split Variable — pp. 268–271

- Formerly Split Temp or Remove Assignments to Parameters.
- Use when one binding represents different concepts at different points in a function.
- Multiple assignments alone are not sufficient evidence: loop counters and accumulators have legitimate evolving roles.
- Identify the first responsibility and give its declaration and initial assignment an appropriate name.
- Make that binding immutable where possible.
- Change its references up to, but not through, the next responsibility-changing assignment.
- Test before repeating for the next lifetime segment.
- Continue until each separate concept has its own binding.
- Assigning to an input parameter can blur original input and subsequent local state; split those roles.
- Preserve genuine accumulation rather than creating one variable per iteration.
- Follow reads and writes, not just lexical text ranges, when branches complicate a variable's lifetime.

## Rename Field — pp. 272–276

- Use when a record field or accessor name no longer describes its domain meaning.
- If the record is truly local, rename every access and test together.
- If usage is broad, Encapsulate Record before migrating its representation.
- Rename private storage and adjust internal references first.
- Test that existing external accessors still behave the same.
- Change constructor-facing names where necessary with Change Function Declaration.
- Rename getters and setters as a separately controlled interface migration.
- A private field rename does not automatically rename serialized or persisted fields.
- Distinguish the representation name from an API name that outside consumers depend on.
- Retain compatibility for published consumers or use the cross-release migration approach in Chapter 2.

## Replace Derived Variable with Query — pp. 277–280

- Use when stored state can be recomputed from authoritative data and updates must be synchronized.
- Inventory every initialization and update to the derived value.
- Use Split Variable if one binding mixes derived and independent responsibilities.
- Write a side-effect-free calculation of the intended derived value.
- Temporarily compare the existing stored value with the calculation at its use points.
- Encapsulate the value if a common assertion or comparison seam is needed.
- Run tests and investigate disagreements before replacing the old result.
- Migrate readers to the calculation and test.
- Remove the obsolete declaration and update machinery once no readers depend on it.
- Keep the source data needed for the calculation; do not delete authoritative state along with its cache.
- This transformation removes the obligation to update two representations consistently.
- It can also clarify meaning that was hidden in distributed incremental updates.
- Exception: immutable source plus immutable derived output is a legitimate transform result.
- Very transient derived structures can also be reasonable when their lifetime is controlled.
- If recomputation cost matters, measure it and design cache invalidation explicitly rather than assuming all caches are wrong.

## Change Reference to Value — pp. 281–284

- Inverse: Change Value to Reference.
- Reference treatment updates the existing nested object; value treatment replaces it with a new equivalent-kind object.
- Use when callers care about the contents, not shared mutable identity.
- Confirm the candidate can become immutable.
- Replace setter-based modification with construction of a new value.
- Remove setting methods from the value object once callers have migrated.
- Provide equality based on relevant fields rather than memory identity.
- Keep hashing consistent with value equality where the language and collection types require it.
- Do not assume a language automatically applies custom equality to all operators or map keys.
- The containing object may still be mutable while its component is an immutable value.
- Replacing an outer reference is not the same as mutating the formerly shared object.
- Do not use this move when existing collaborators must all observe the same object's updates.
- Check nested contents: an apparently immutable wrapper can still expose mutable members.

## Change Value to Reference — pp. 285–288

- Inverse: Change Reference to Value.
- Use when multiple copies represent one logical entity whose updates must be visible to all collaborators.
- Identify the entity's stable key and intended ownership of its authoritative state.
- Find or create a repository of canonical instances.
- Ensure constructors or factories can look up the correct related entity.
- Change each host-object construction path to obtain its related instance from that repository.
- Test after each construction-path migration.
- Verify that two hosts for the same logical entity now share the intended instance.
- Verify that different entity identities remain distinct.
- Decide how a new instance enters the repository so later lookups do not create duplicates.
- Do not introduce ambient global access unnecessarily; preserve explicit access to the repository where practical.
- Existing copies may disagree; that conflict requires resolution, not a silent last-write-wins accident.
- Memory savings alone are not the central motivation; consistent shared updates are.

## Value/reference decision table

| Requirement | Usually favors | Main obligation |
|---|---|---|
| Equivalent contents should be interchangeable | Value | Immutability and meaningful equality |
| Several holders must observe one entity's changes | Reference | Canonical identity and controlled updates |
| Snapshot must retain its historical meaning | Value or explicit snapshot | Do not replace it with a live query |
| Output is derived from immutable input | Transform record | Preserve immutability or bounded lifetime |
| Stored derivation is frequently stale | Query | Establish equivalent calculation before removing storage |

## Common category errors

- A variable reassignment does not necessarily mean multiple responsibilities.
- A `const` binding does not establish value semantics for a mutable object.
- The same field values do not necessarily mean the same entity.
- A stored cache is not necessarily the source of truth.
- Repeated copies are not necessarily a bug if they intentionally preserve independent snapshots.
- A field rename is not harmless if external formats or reflective code use its name.

## Verification prompts

- Can tests distinguish a snapshot from a live view after the source changes?
- Can tests distinguish same-content values from distinct entity identities?
- Do equality and hashing agree for the collections actually used?
- Have all update sites been found before deleting derived storage?
- Do the final tests exercise both construction and subsequent modification?
