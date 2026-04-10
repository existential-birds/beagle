# Pressure-test scenarios

Expected behaviors for the strategy-review skill. Use these to validate that the skill handles common review entry points correctly.

| Scenario | Expected behavior |
|----------|-------------------|
| User provides a standalone goals document (all aspirations, no diagnosis) | Name it: "This reads more like a goals document than a strategy." Rate Diagnosis as Missing, Bad-Strategy Patterns as Weak (goals masquerading as strategy). Offer to help identify the missing strategic elements. |
| User provides `strategy-draft.md` only, notes exist but weren't offered | Ask for `strategy-notes.md` — the notes dramatically enrich the review. Proceed without if user declines. |
| Draft + notes mismatch: notes contain sharper thinking than draft | Flag in Notes Cross-Reference: "The interview produced a sharper diagnosis than the draft contains." Quote both versions. |
| Polished board deck with weak diagnosis | Calibrate to near-final maturity — higher bar, flag everything that undermines credibility. Focus on the diagnosis gap specifically because a polished presentation with a vague diagnosis is the most dangerous kind of bad strategy. |
| Comparative review: two competing proposals | Review each independently first using the seven dimensions, then compare. Don't declare a winner unless structural quality clearly differs. |
| Mid-interview provisional draft (`[PROVISIONAL]` tag) | Produce a "mid-interview check" with 3-5 observations, not a full review. Focus on strongest and weakest emerging kernel elements. Suggest questions to pressure-test before finalizing. |
| Strategy with sourced market claims | Check which claims are sourced vs. asserted. Flag conventional wisdom presented as fact. Note claims you can't verify: "I can't verify this, but if wrong, the strategy changes." If durable state is active, tag claims in `source-evidence.md`. |
| Long multi-appendix document (>3,000 words) | Activate durable review state. Extract evidence to `source-evidence.md` during reading. Compose final review from artifacts, not conversation memory. |
| User says "poke holes in this" or "quick take" | Deliver findings inline in chat — lead with Critical Findings, top failure path, recommendations. Offer to write full `strategy-review.md` afterward. Do not write the file without confirming. |
| Strategy already in execution (post-hoc review) | Focus on assumption validation — which assumptions can now be checked against reality? Flag any already falsified by events. |
| Strategy uses OKRs/V2MOM/SWOT instead of kernel language | Evaluate the thinking, not the format. Map concepts to kernel. Flag genuine structural gaps ("this V2MOM has methods but no diagnosis") rather than forcing vocabulary. |
