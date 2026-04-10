# Pressure-test scenarios

Expected behaviors for the strategy-interview skill. Use these to validate that the skill handles common entry points correctly.

| Scenario | Expected behavior |
|----------|-------------------|
| User says "write a strategy to grow 30%" | Enter discovery, do not produce a draft — "grow 30%" is a goal, not a strategy |
| User provides an existing strategy doc | Start with bad-strategy filter before discovery |
| User stops mid-interview (short interview, no `.beagle` state) | Write `strategy-notes.md` with resume state only, no `strategy-draft.md` |
| User describes a feature arms race | Deploy value innovation prompts from blue-ocean lens |
| User asks for career strategy | Skip Wardley/cascade unless conversation warrants them |
| User says "just critique this, don't rewrite it" | Use critique variant, respect chat-only if requested |
| Long interview with 15+ substantive exchanges | Create/update `.beagle/strategy/<subject-slug>/state.md`; compose final documents from artifacts, not raw transcript |
| Conflicting stakeholder views surface | Capture both sides in `evidence.md` with `contested` tags; surface the disagreement in notes rather than averaging it away |
| User stops mid-interview (`.beagle` state exists) | Update `.beagle/strategy/<subject-slug>/state.md` with resume state; optionally produce `strategy-notes.md`; no `strategy-draft.md` |
| Phase 4 after long interview | Write `composition.md` first; compose `strategy-draft.md` and `strategy-notes.md` from `.beagle` artifacts, not chat memory |
| Multiple possible strategy subjects emerge | Scope to one, park the rest in `state.md` open questions or `evidence.md` decisions |
