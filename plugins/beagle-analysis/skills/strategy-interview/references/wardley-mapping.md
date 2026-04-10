# Landscape Mapping: Seeing the Terrain Before Choosing the Route

Use this reference when the user's situation involves **competitive positioning, technology choices, build-vs-buy decisions, or understanding where an industry is heading**. It adds a layer of situational awareness to Phase 1 (Discovery) that sharpens the diagnosis.

**When to skip this entirely:** Personal strategies (career pivots, side projects), team-level process improvements, or any situation where the user is the only actor and there is no competitive landscape to map. If nobody is competing for the same users or resources, landscape mapping adds weight without insight.

## Core concepts (for the interviewer's mental model, not for lecturing)

### Value chain

Every user need is served by a chain of components. The user sees the top; underneath are layers of capabilities, technologies, and activities that make it work.

**Example:** A customer books a hotel room (visible need). Underneath: search interface, availability engine, payment processing, room inventory database, channel manager, property management system.

The strategic question is always: **which components in the chain do you control, which do you depend on, and which are changing?**

### Evolution stages

Every component moves through a lifecycle, left to right:

| Stage | Character | Feels like | Example |
|---|---|---|---|
| **Genesis** | Novel, uncertain, requires exploration | Research project | First LLM agents (2023) |
| **Custom-built** | Understood but bespoke, no standard approach | Internal tooling | Most company data pipelines today |
| **Product** | Standardized, multiple providers, feature competition | Buying software | CRM systems, CI/CD platforms |
| **Commodity/Utility** | Invisible, pay-per-use, interchangeable | Turning on a tap | Cloud compute, email delivery, payment processing |

Components only move right. They never move back. The speed varies, but the direction doesn't.

**Why this matters for diagnosis:** If someone is building custom what has already become product, they're burning resources for no advantage. If they're treating a genesis-stage component as commodity (buying an off-the-shelf solution for something nobody has figured out yet), they'll get a mediocre version of something that requires invention.

### Movement patterns

These are the forces that move components rightward:

- **Competition** drives evolution. More suppliers, more users, more standardization.
- **Componentization** — yesterday's product becomes tomorrow's building block (AWS turned servers into API calls; that enabled a generation of startups that couldn't have existed before).
- **Co-evolution** — when an underlying component commoditizes, practices built on top of it change. Cheap compute didn't just make the same things cheaper; it made entirely new architectures possible (microservices, serverless, ML training at scale).

### Value capture dynamics

Knowing where components sit on the evolution curve is half the picture. The other half is understanding who captures the economic value at each layer. A company can control every component in its chain and still make no money if value concentrates at a layer controlled by someone else.

**The pattern:** As components commoditize, margin migrates. It moves away from the commodity layer and toward adjacent layers that are still differentiated. If you're operating in the commodity layer and your supplier operates in the product layer, they capture the margin — you compete on price while they compete on features.

**Why this matters for diagnosis:** Many strategies fail not because the company chose the wrong market but because they're positioned at the wrong layer of value capture. They built the best version of something that was becoming interchangeable, while the real margin moved upstream or downstream.

**Interview probes:**

- "Where in your value chain does the margin actually sit today? Who captures it — you, your suppliers, or your customers?"
- "If your layer commoditizes further, where does the value migrate? Who's positioned to capture it?"
- "Is your competitive advantage at the layer where value is currently captured, or a different one?"
- "When you look at how your industry's economics have shifted over the past five years, which layer gained pricing power and which layer lost it?"

## Interview application

### Extracting the value chain through conversation

Don't ask the user to "draw a map." Instead, ask questions that surface the chain and where things sit on the evolution axis.

**Start from the user need and work down:**

- "Who is the end user, and what are they actually trying to accomplish when they interact with you?"
- "What has to happen behind the scenes for that to work? Walk me through the chain — what depends on what?"
- "Which of those pieces do you build yourself, and which do you buy or rent?"

**Identify evolution stage for each important component:**

- "Is this something you had to figure out from scratch, or did you follow a known playbook?"
- "How many other companies solve this the same way you do? Could you swap in a vendor tomorrow, or is this deeply custom?"
- "If you stopped maintaining this, could you buy a replacement off the shelf? How close is that replacement to what you need?"
- "Is this something that felt novel three years ago but now feels like table stakes?"

**Find the tension points:**

- "Where are you building custom when you suspect you could be buying?"
- "Where are you buying something generic when you think your situation actually requires something purpose-built?"
- "Which piece of this chain keeps you up at night — the one where if it breaks, everything breaks?"

### Using the map to sharpen the diagnosis

Once you have a rough picture of the value chain and where components sit, use it to pressure-test the user's framing. These are the most common patterns that landscape mapping reveals:

#### Building custom what's becoming commodity

**What it sounds like:** The user describes heavy investment in a capability that multiple vendors now offer as a product or service.

**Interview probe:** "You mentioned you have a team of four maintaining your internal [X]. Three vendors now sell this as a service. What does your version do that theirs doesn't — and is that difference actually strategic, or is it historical accident?"

**Why it matters for diagnosis:** Resources locked into commodity work can't be deployed where the real differentiation lives. This is one of the most common sources of strategic incoherence — the org *says* its advantage is in area A but *spends* its engineering budget maintaining area B.

#### Treating genesis as commodity

**What it sounds like:** The user plans to "just buy" or "quickly implement" something that nobody in their industry has figured out yet.

**Interview probe:** "You're describing this as a procurement decision, but I'm not hearing about anyone who's solved it well yet. Is this actually a problem someone has productized, or are you going to end up building it anyway after the vendor disappoints?"

**Why it matters for diagnosis:** Buying something that doesn't exist yet as a reliable product leads to painful vendor lock-in with an immature solution, or an expensive rewrite when the off-the-shelf version doesn't fit.

#### Competitor is further along the evolution curve

**What it sounds like:** A competitor has already industrialized a component the user is still building by hand.

**Interview probe:** "Your competitor launched [X] as a self-serve product last quarter. You're still doing it with a manual process and three engineers. What does that gap cost you in speed, and how long before it costs you customers?"

**Why it matters for diagnosis:** If a competitor has already commoditized a component you're still building custom, matching them by building your own version is the wrong move — you'll always be behind. The strategic question becomes: can you leapfrog by adopting their commodity version (or a third-party equivalent) and competing on a different layer of the stack?

#### Inertia masking a shift

**What it sounds like:** The user describes their competitive advantage in terms of a component that is visibly commoditizing but they haven't acknowledged the shift.

**Interview probe:** "You described [X] as your core differentiator. Two years ago I'd agree — but now [competitor A] and [competitor B] offer something similar as a feature. If [X] becomes table stakes in the next 18 months, where does your advantage actually live?"

**Why it matters for diagnosis:** Inertia — emotional attachment to past investments, organizational identity built around a capability — is the most common reason strategies fail to adapt. The landscape moved; the strategy didn't.

#### A component is about to be disrupted

**What it sounds like:** A layer of the user's value chain is being commoditized by a new entrant or technology shift, and the user hasn't factored this into their planning.

**Interview probe:** "If [new technology / new entrant] makes [component] essentially free or trivially easy in the next two years, what happens to your business model? Which assumptions break?"

**Why it matters for diagnosis:** The most dangerous disruptions aren't the ones that destroy your product — they're the ones that destroy the *economics* of a component you depend on, changing who captures value in the chain.

## What good landscape-informed diagnosis sounds like

After working through the value chain, the diagnosis should be able to say something like:

- "We're spending 40% of engineering on infrastructure that has become commodity — freeing that up and redeploying it to [genesis-stage capability] is the structural move."
- "Our competitor commoditized [X] two years ahead of us. Competing on [X] is a losing game. The opening is in [Y], which they've neglected because they're organized around [X]."
- "The entire middle layer of our stack is about to be disrupted by [technology shift]. Our strategy needs to assume that layer becomes free and figure out where we create value above or below it."
- "We're treating [component] as a buy decision, but nobody sells what we actually need. This is a genesis problem disguised as a procurement problem, and it needs R&D investment, not a vendor eval."

These are concrete, falsifiable, and they lead directly to a guiding policy. That's the test.

## Posture

Use this framework to ask better questions during discovery, not to deliver a mapping tutorial. The user should never feel like they're being walked through a methodology — they should feel like you're asking unusually sharp questions about where their market is heading and where their resources are actually going.

If the user starts using evolution language on their own ("that's becoming commodity," "we're still in the early stages of figuring this out"), run with it. If they don't, that's fine — the insight shows up in the diagnosis, not in the vocabulary.
