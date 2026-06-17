# The Diataxis Compass, Map, and Quality Model

The canonical reference for choosing a documentation type and judging its quality, drawn from the [Diataxis framework](https://diataxis.fr/). This file is **self-contained**: every Beagle documentation skill links here, but it carries no dependency on the others, so it remains usable even when a single skill is installed on its own.

Use it to answer three questions:

1. **Which type should I write?** → The Compass.
2. **How do the four types relate?** → The Map.
3. **Is what I wrote any good?** → The Quality model.

## The two axes

Diataxis observes that all documentation serves a craft, and a craft is learned and practised along two axes:

- **Action ↔ Cognition** — practical knowledge (*knowing how*, doing) versus theoretical knowledge (*knowing that*, thinking).
- **Acquisition ↔ Application** — *studying* to acquire skill versus *working* to apply it.

> "These two axes don't just cover the entire territory, they define it. This is why there are necessarily four quarters to it, and there could not be three, or five."

## The Map (2×2)

| | **Action** (informs *doing*) | **Cognition** (informs *thinking*) |
|---|---|---|
| **Acquisition** (study / learning) | **Tutorial** | **Explanation** |
| **Application** (work / a goal) | **How-To guide** | **Reference** |

One-line identity of each type:

- **Tutorial** — *learning-oriented.* A lesson under the guidance of a teacher. Builds competence and confidence through a guaranteed-to-succeed, hands-on experience.
- **How-To guide** — *task-oriented.* Directs an already-competent user through the steps to reach a real-world goal.
- **Reference** — *information-oriented.* Austere, authoritative description of the machinery, consulted while working.
- **Explanation** — *understanding-oriented.* Discursive discussion of *why* — context, alternatives, trade-offs — read away from the keyboard.

## The Compass: choosing a type

> "To use the compass, just two questions need to be asked: *action or cognition? acquisition or application?*"

| If the content… | …and serves the user's… | …it is a… |
|---|---|---|
| informs **action** | **acquisition** (study) | **Tutorial** |
| informs **action** | **application** (work) | **How-To guide** |
| informs **cognition** | **application** (work) | **Reference** |
| informs **cognition** | **acquisition** (study) | **Explanation** |

A faster phrasing for a single document or request:

| The reader's stance | Type |
|---|---|
| "I'm learning — guide my hands" | **Tutorial** |
| "I have a goal — help me reach it" | **How-To** |
| "I'm working — let me look something up" | **Reference** |
| "I'm reflecting — help me understand why" | **Explanation** |

## The two distinctions that resolve most ambiguity

**Tutorial vs. How-To** — both are action-oriented sequences, so they are easily confused. The split is **study vs. work**, not difficulty:

- A *tutorial* is a lesson; the teacher owns the agenda, eliminates the unexpected, and is responsible if the learner fails.
- A *how-to guide* is a recipe; the user owns the agenda, brings their own real-world context, and the guide must prepare for branching and the unexpected.
- Analogy: teaching a child to cook (tutorial) vs. a recipe for someone who already cooks (how-to).

**Reference vs. Explanation** — both are cognition-oriented, so they too blur together. The split is **work vs. study**:

- *Reference* is **bounded by the product/machinery**: neutral, austere facts you consult while working. "Describe, and only describe."
- *Explanation* is **bounded by a topic**: discursive prose you read while reflecting. It discusses, weighs, and connects.
- Litmus test: would the reader consult this *while actively working*, or only *after stepping away to reflect*?

## Why not mix types

Each type meets a distinct user need; blending them dilutes all of them. Explanation inside a tutorial gets in the way of doing. Reference interrupted by digressions stops being scannable. Instruction smuggled into explanation stops it from developing its own argument. When a document tries to do two jobs, **split it** and link the halves together.

## Quality: two dimensions

Diataxis distinguishes two kinds of quality, and the second depends on the first.

**Functional quality** — objective, measurable against the world. A document either has these or it does not:

- **accuracy** — it is correct
- **completeness** — nothing required is missing
- **consistency** — terms, structure, and format match across the docs
- **usefulness** — it serves a real user need
- **precision** — it says exactly what it means

Functional quality is a prerequisite. It takes discipline and attention to detail, and Diataxis alone cannot supply it — but the framework *exposes* functional gaps by forcing each type to do one job well.

**Deep quality** — subjective, human-centred, and recognisable rather than measurable. It is *conditional on functional quality* — you cannot reach it without the foundation:

- feels good to use; has flow
- anticipates the user's needs
- fits the way people actually work
- is, in a word, beautiful

Organising documentation around genuine user needs (which is what the Compass enforces) is what lays the conditions for deep quality.

## How to apply Diataxis: work by improvement

Diataxis is **not** a set of four empty boxes to fill in up front. It "discourages planning and top-down workflows, preferring instead small, responsive iterations."

The working cycle:

1. **Choose** one thing — however small — that you can improve now.
2. **Assess** it against Diataxis: Does it serve a single, clear user need? Is it the right type? Is the language right for that type?
3. **Decide** a single next action.
4. **Do it** and publish.

Don't build skeleton trees of empty sections. "Diataxis changes the structure of your documentation from the inside." Documentation is never finished, yet at each step it stays complete.

Scaling note: for large doc sets, group by type behind landing pages; "seven items seems to be a comfortable general limit" for any one list.
