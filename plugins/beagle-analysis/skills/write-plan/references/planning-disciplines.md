# Planning Disciplines

The rules that govern what goes *inside* a task. Load this at drafting time — when you are writing task bodies — not when deciding whether to plan at all.

Nine disciplines, in the order they bite:

1. [Code in Steps](#code-in-steps-tests-yes-implementations-as-skeletons) — what gets real code and what gets a contract
2. [The Recoverability Test](#the-recoverability-test) — what to delete
3. [Test Authoring](#test-authoring-discipline) — the Step 1 body
4. [Behavior Contract](#behavior-contract-discipline) — the Step 3 body
5. [Failure Propagation](#failure-propagation-policy) — error handling in every contract
6. [Cleanup](#cleanup-discipline) — the Step 5 sweep
7. [Patterns and the Application Audit](#patterns-naming-repetition-once) — repetition across N sites
8. [Spike Before Plan-Lock](#spike-before-plan-lock) — unverified tool behavior
9. [Parallel-Implementation Gate](#parallel-implementation-gate) — second backends and adapters

---

## Code in Steps: Tests Yes, Implementations As Skeletons

The plan's job is to lock down the **contract** for each task. Tests are the contract; implementations satisfy it.

**Show real, exact code for:**

- **Test step bodies** — the assertion is the contract. If a test asserts the wrong thing, the impl can be wrong and the suite still passes. Write tests precisely, in the project's language, with the actual functions and types they will use.
- **Helper signatures** — when a test calls a helper the executor will write or reuse, give its full signature (`seed_entries(&store, session_id: Uuid, count: i64) -> Vec<EntryId>`). The signature is cheap and removes a guess; the body is not the plan's job.
- **Commands** — exact test, migration, lint, and typecheck commands. Not paraphrases.
- **Commit messages** — exact strings.
- **Configuration changes** — exact diffs where the value is the contract (dependency versions, feature flags, env vars).

**For implementation steps, give a contract plus a skeleton — never a finished implementation.**

Every Step 3 carries:

- **Files touched** — exact paths.
- **Behavior contract** — 3-5 bullets of concrete observable behavior, verifiable against the Step 1 test.
- **Reference** — `file.ext:line-line` pointer to the closest analog. Pointer only.
- **Skeleton** — for any non-trivial step, the function signature(s) being added or changed, plus the control-flow shape as comments. Example:

  ```rust
  fn compact_entries(store: &Store, before: Seq, summary: &str) -> Result<Seq, Error> {
      // 1. load entries with seq < before
      // 2. write summary row at the lowest evicted seq
      // 3. delete the evicted range in the same transaction
      // 4. return the summary row's seq
  }
  ```

  Signature plus numbered comments. **No bodies, no expression-level code** — those depend on real types and adjacent code the executor can see and you cannot.

A step is trivial (skeleton optional) when it is a one-line change, a config edit, or a pure rename. Everything else gets a skeleton.

Why a skeleton and not the full impl: a pre-written implementation is almost always wrong by the time execution starts, and the executor then has to reconcile real code against the planner's guess — worse than no sketch. A signature plus a numbered control flow is not wrong in that way: it pins the decomposition without pretending to know the types.

"Behavior contract" means *concrete observable behavior the test will verify*. "Handle errors" is forbidden; "if the input contains a duplicate id, return an `Err` of the project's error type with a message naming the duplicate id" is required.

The discipline is: **the plan defines what counts as correct and how the work decomposes; the executor writes code that meets it.**

## The Recoverability Test

After drafting each step, re-read it and ask:

> "Does the executor need this line, or can they recover it by reading the referenced file?"

Delete anything they can recover. A plan is the minimum delta the executor cannot derive — not a re-creation of the codebase in markdown.

- **Test bodies:** the executor writes the seed loop; show the assertions and the call site. They cannot recover *which assertion pins the spec*.
- **Behavior contracts:** the executor reads the analogous impl; point at it with `file.ext:line-line`. They cannot recover *what makes this task different from the reference*.
- **Reference blocks:** a reference is a pointer (`launch.rs:397-400`). Pasting the cited code inline is duplication that rots the moment the code shifts.
- **Sweep targets:** these are the exception — enumerate them by name (see [Cleanup](#cleanup-discipline)). A sweep is not recoverable by reading one file, because the executor does not know what the change made stale.

A plan that fails the recoverability test is verbose, not specific. **Verbosity ≠ specificity.** Specificity is one sentence that pins the right invariant.

## Test Authoring Discipline

Four rules for the test code in Step 1.

**A contract is the minimum text that, if violated, makes the test fail.** If a test body grows past ~15 lines, you are re-deriving setup. The assertions are the contract; the setup is plumbing.

**Show the assertions and the call site. Skip the seed loop — but name its helper with a full signature.** A compaction test does not need five `SessionEntry` values constructed inline. It needs the call to `compact_entries(_, N, summary)`, the assertions on what `load_entries` then returns, and the assertion on the summary row's `seq`. Name the seeder as `seed_entries(&store, session_id: Uuid, count: i64)` so the executor writes the right thing.

**Reuse first; invent only when nothing fits.** Before writing a fresh `make_user()`, fixture, or fake pool, grep for an existing one with the same shape. Existing helpers already encode correct cleanup, realistic data, and project-typical error handling. When the plan must introduce a new helper, name a specific existing one that was considered and why it did not fit. "I didn't grep" is not a reason.

**Pin the spec, not every conceivable edge case.** One precise test per behavior the spec calls out, plus one per named bug class. If you are writing the 5th boundary test for the same function "just in case," stop — marginal coverage is negative once maintenance and suite noise are counted. Speculative input-space exhaustion belongs in property tests or fuzz harnesses.

**Exception — payload-preservation invariants.** When a test pins a preserve/recover/transform invariant (output survives truncation, data round-trips, ordering holds), the structurally-distinct producers and the corrupted region are NOT speculative edge cases — they ARE the spec. Enumerate every producer whose data path differs (streaming-with-eviction vs. whole-string) and assert the sentinel in the damaged region for each. Collapsing these to one happy-path producer is exactly how a recovery test passes against the one tool that has the bug.

## Behavior Contract Discipline

**3-5 bullets is the target. Past 5, replace the rest with a reference.** The contract enumerates what is *new or different* about this task's impl. Shape, error handling, codecs, helpers — all of that is in the referenced analog. Twelve bullets describing types, indexes, fields, and rationale is the implementation re-derived in markdown. Replace with: `Schema matches <reference migration file> with <one-sentence delta>`. Specificity is the delta from the reference, not the full state.

**References point, they do not paste.** A reference is `core/session/pg.rs:271-309`. Inline code blocks under "Reference:" duplicate what the executor reads anyway and rot when the code shifts. If you are pasting more than a signature, you have turned the reference into a re-implementation.

## Failure-Propagation Policy

**Non-optional in every contract that introduces a fallible operation** — serialization, deserialization, parsing, type conversion, network call, file open, anything that can return an error. The contract MUST state how the error propagates.

- **Required policy** for boundary-internal paths (anything running after input has been validated): propagate via the project's error type — `?` / `change_context` / `map_err`. The caller decides.
- **Forbidden patterns:** `.unwrap_or(<non-default fallback>)` coercing a None or Err into a plausible-looking placeholder; `.unwrap_or_default()` on a type whose default is a meaningful value (empty string, zero ID, default enum variant); silent `.ok()` discarding the error.
- **Allowed exceptions** only when the contract spells them out: a true default the type system makes obvious (an empty vec when "no results" is the spec'd outcome), plus one sentence naming why the default is correct.

"Serialize the entry_type to the row" is insufficient. "Serialize via `to_value()?`; coerce to string via `.as_str().ok_or_else(...)?`; never silently substitute a fallback variant" is the contract. If the plan does not state the policy, the executor reaches for `unwrap_or` and the bug ships.

## Cleanup Discipline

Every task that **modifies an existing file** ends with a sweep removing what the change made stale. This is part of the task, not a later phase.

The sweep covers, in the files this task touched:

- Comments referencing the old behavior, name, or signature
- Imports used only by deleted code
- Parameters, struct fields, enum variants, or helpers used only by replaced call sites
- Dead match arms, unreachable branches, unused private functions
- Stale doc-comments — especially phase/PR/ticket citations no longer load-bearing

**Enumerate the targets by name in Step 5.** Not "sweep the file," and not line numbers (which rot). Write the list: "remove the `PgPool` import, the `session_store_override` field, the `// returns the PG pool` doc-comment on `Store::new`, and the now-unreachable `Backend::Legacy` match arm." The executor greps for each named symbol and reports per item. An unenumerated sweep is a prove-a-negative and has no terminating check.

A task that adds the new thing but leaves old comments, imports, and dead helpers behind is **not done** — it shipped a partial change.

**Exceptions:** tasks that only create new files have nothing to sweep; tasks that only edit configuration sweep only those config files.

This is separate from dedicated `Cleanup` tasks that close out residue in files no other task touched. Both can exist in one plan.

## Patterns: Naming Repetition Once

When the same transformation applies across many sites ("convert N call sites to a new API", "migrate N test files to a new fixture"), name the pattern once in a **Patterns** section at the top of the plan and reference it from each task. Each task that uses the pattern still:

- Names its specific files (no "see file list")
- Writes its own test step with real assertions
- Has its own commit with its own message

The Patterns section absorbs only the *transformation shape* and the *reference example* — never the test, never the commit. A downstream agent must be able to execute one task without reading the others.

### Pattern Application Audit

When a Pattern is applied across many sites, the plan **must** include a final `Audit: <pattern name>` task immediately after the last site-conversion task.

The audit is **one bounded check**, not a sweep:

> **Budget:** one pass, fixed sample of 3 sites. **Stop condition:** each of the 3 sampled sites has a recorded verdict. **Tie-break:** record what was found and proceed — do not widen the sample.

The audit task body must, at planning time, **enumerate the converted sites** (`file:line` each) and mark which depend on production-specific configuration the new pattern does not replicate — pool settings, timeouts, isolation levels, env, signal handlers. Not "check the sites": "site A at `file:line` depends on X; site B at `file:line` depends on Y." Fix each named divergence in the audit task or open a numbered follow-up task.

Then the executor picks 3 of the enumerated sites, runs the corresponding production-wiring test (the project's tier-2/tier-3 equivalent), and records pass/fail per site. If a sampled site regresses, the pattern needs a per-site escape hatch — name it and stop.

Do **not** ask for "grep-confirm zero remaining old-pattern sites." Exhaustive absence over an open search space has no terminating check (`beagle-core:verification-budget`, prove-a-negative ban). The planner's enumerated site list *is* the completeness check; the sample is the correctness check.

Patterns applied blindly across N sites are how production-config divergence ships green — test pool config silently diverging from production pool config, for instance. The enumeration forces the planner to look; the sample forces the executor to verify.

## Spike Before Plan-Lock

Plans written from documentation alone bake in toolchain assumptions that fail on first contact with the codebase. Before locking the plan, identify every claim of the form "tool X supports behavior Y" or "command Z produces output W" where neither this repo nor the team has a working example. Each is a **spike candidate**.

For every spike candidate the plan **must** include a `Task 0: Spike <claim>` whose body is:

1. Run the canonical command(s) the rest of the plan depends on, against this repo, as a documented step.
2. Capture the actual output — success path AND failure modes.
3. Record whether the Key Decision survived.

Spike-required claims look like:

- "Tool X's `--workspace` flag handles this repo's multi-backend layout in one invocation."
- "Library Y's default test attribute uses the same pool config production uses."
- "Migration framework W handles concurrent migrators against a fresh DB idempotently."
- **Input-shape assumption:** the spec assumes upstream input arrives whole / sorted / deduped / complete / already-validated, but nobody verified that shape holds in *this* repo. (One retention spec assumed "tool output arrives whole"; for streaming tools it does not — a rolling buffer had already evicted the prefix upstream.) A load-bearing assumption about upstream data shape is a spike candidate, not a given.

**When the spike disproves its assumption, the executor records the finding, emits the stop-and-report block, and halts.** The executor does not redesign, re-sequence, or rewrite the spec — a disproven assumption invalidates planning-tier decisions and the executor has no charter to remake them. Revising the spec is *your* job as planner, on the next pass. Write Task 0 so it says this explicitly.

This rule is stricter than the Assumption Audit. An assumption is "I'm guessing about behavior I haven't verified." A spike candidate is "the spec made a load-bearing decision about behavior nobody verified." The first is documented; the second is run.

## Parallel-Implementation Gate

When the plan adds a parallel implementation of an existing capability — a second database backend behind the same trait, a second platform target for the same UI, a second protocol adapter for the same service — the plan **must** end with a final task whose body is:

1. Identify the canonical contract/conformance suite that pins the existing implementation's observable behavior.
2. Run that suite against **both** implementations in the same invocation.
3. Assert identical observable behavior — return values, persistent rows, emitted events, error variants. Internal struct layout does not count.
4. Fail the task if either implementation's contract test is red against the captured baseline.

This task is the final gate and is non-optional. Without it, a plan that "implements the second backend in parallel" ships divergence: the executor declares each backend's tasks done in isolation while the contract test — which sees both — stays red unnoticed.

The behavior-equivalence gate is separate from per-task contract tests. Per-task tests pin one implementation's behavior. The gate proves they agree.
