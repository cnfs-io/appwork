# Architecture — what Chorus tests (and what it doesn't)

**Status: design principle, binding now.** This fixes the boundary of Chorus's
own test responsibility. It exists because Chorus is a *harness*, and a harness
can only honestly test some things about itself.

## Chorus is an organizational harness

Chorus provides infrastructure an org leverages — agents + skills applied to
goals, projects, and issues, coordinated through an org-chart-shaped domain. It
deliberately does **not** define what the org does or what "done" means. That
refusal is the whole point of the design, and it determines what Chorus can test.

## Two claims; only one is Chorus's to make

**Claim 1 — the harness is internally sound.** Models compose, associations hold,
the intent spine resolves (an Issue reaches its Strategy through
Project → Goal), a Workspace hosts a Project serially, an Agent can
claim an Issue. This is structural integrity, fully testable inside Chorus
against synthetic data, with no notion of what any real org does. **Chorus owns
this.**

**Claim 2 — the harness actually gets real things done.** Agents + skills applied
to goals produce useful outcomes. This is *efficacy*, and Chorus **cannot test it
even in principle**, because efficacy is only meaningful relative to a domain and
the domain is exactly what Chorus refuses to own. Any Chorus test asserting
"this produced something useful" would have to invent a domain to define
"useful" — smuggling opinions into the non-opinionated framework through the test
suite. **Efficacy belongs to Factory and lgat-admin**, the real orgs that define
what "done" means. This is not "better tested downstream"; it is *categorically*
downstream.

## The right ceiling for Chorus's suite: the lifecycle claim

Between "associations hold" and "produces useful work" sits the strongest claim
Chorus *can* make about itself:

**Claim 1.5 — the harness supports a complete coordination lifecycle, end to end,
against a synthetic domain.** Not "did it produce something useful," but "can the
mechanics flow all the way through": a Strategy spins up a
Goal, the Goal a Project, the Project Issues; a Workspace takes the Project into
its active slot with Artifacts attached; Agents claim Issues, move them through
states, complete them; Issues resolve and the Workspace frees up.

The synthetic domain ("Acme makes widgets"; "Issue: paint the widget blue") is a
**feature, not a compromise** — keeping the domain deliberately meaningless is how
the test exercises the harness *as* a harness without accidentally encoding
opinions about any real domain. If the lifecycle does not compose cleanly against
a toy domain, that must be discovered in Chorus's own suite, before a real org
hits it.

## Where the line sits, concretely

- **In Chorus:** model specs (associations, validations, `dependent:` behavior),
  plus a lifecycle/workflow integration spec walking the full coordination cycle
  against a synthetic org. When heartbeat/checkout land (the heartbeat-and-checkout
  plan, `doc/plans/003`), that spec extends to cover claim/lease/release end to
  end. Never any efficacy assertion.
- **In Factory / lgat-admin:** "given our real domain, does running this harness
  produce the outcomes we care about." Agents + skills pointed at real goals;
  the org actually functioning. These hosts own "done."

## Consequence for content storage / chorus-storage

The lifecycle integration test does **not** need real content storage — a
synthetic domain uses trivial stubbed/inline content. So Chorus can prove its
harness sound (Claim 1.5) without the content seam existing. The seam and any
downstream content store are driven by **Factory's** real content needs
(Claim 2), not by Chorus's self-integrity — narrative content lives in OKF
concepts (`has_one_okf`), and no content columns sit on Chorus's own domain
tables. Chorus does not block on the seam to validate itself.
