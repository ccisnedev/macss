# The Grant Envelope — Specification v0.1

| | |
|---|---|
| **Status** | Draft |
| **Author** | Carlos Cisneros (@ccisnedev) |
| **License** | MIT |
| **Realizes** | ADR 0006 — *Autonomy is granted, not approved* |
| **Schema** | [`grant-envelope.schema.json`](grant-envelope.schema.json) |

The key words MUST, MUST NOT, SHOULD and MAY are to be read as described in RFC 2119.

---

## 1. Purpose

ADR 0006 decided that **accountability attaches to the grant, not to the act**: a human decides in
advance, in writing, which capabilities an executor has and within what bounds, and the executor
then acts freely inside that grant. The ADR closes by noting that the model extends past agents to
anything that executes on someone's behalf without asking each time: a pipeline, a scheduled job, a
reconciliation loop.

This document specifies the artifact that carries the grant: the **envelope**. It defines:

1. the envelope document (§3) and its schema;
2. the invariants every conforming implementation holds (§4);
3. how a proposed action is decided against an envelope (§5);
4. a taxonomy of drift between declared and observed state (§6);
5. the semantics of escalation (§7);
6. the attestation emitted for every decision (§8).

It does not specify an implementation. Any number of enforcement points (a tool facade, an API
proxy, an admission webhook) can conform to it.

### 1.1 The problem, in one table

There are two established ways to govern an executor that changes real systems, and each loses
something the other keeps:

| Model | Reacts on its own | Authorized in advance | Evidence without extra work |
|---|---|---|---|
| **Per-act approval** (plan → approve → apply; approval queues) | No | Yes | Partial |
| **Unbounded autonomy** (a reconciler or agent that acts by its own logic) | Yes | No | Partial |
| **Envelope** | **Yes** | **Yes** | **Yes** |

The way out is to notice that **one human approval need not authorize one execution. It can
authorize a bounded space of future actions.** The envelope is that space, written down, signed,
and made to expire.

### 1.2 The analogy

A **limited power of attorney**. You do not give your attorney unlimited power, nor ask them to call
you for every errand. You sign a document that says: *may pay utility bills up to 500, renew the
lease on the same terms, and collect mail — until 31 December. Anything else, ask me.*

That is an envelope: **delegated authority that is bounded, signed, expiring and revocable**, with a
record of every act performed under it. The enforcement point is the notary who checks, at every
act, that the attorney is inside their power.

---

## 2. Terminology

| Term | Meaning |
|---|---|
| **Executor** | The system that proposes actions: an agent, a reconciler, a pipeline, a job, or a person using a tool. ADR 0006 calls it the *grantee* |
| **Grantor** | The humans who sign the envelope. At least a **requester** and an **approver** |
| **Enforcement point** | The component between the executor and the target that decides every proposed action against the active envelope. ADR 0006 calls it the *facade* |
| **Action** | A verb applied to a resource: `refund` on `ticket:4812`, `reprovision` on `node:03` |
| **Resource** | Anything an action targets, named by a URI or URI pattern |
| **Grant** | One entry of an envelope: an action, the resources it covers, and its bounds |
| **Bound** | A limit that is part of a grant: a count, a rate, a value, a time window |
| **Basis** | The approved change the envelope derives from, when there is one: a plan, a pull request, a policy version |
| **Decision** | The outcome of evaluating one action: `allow`, `deny` or `escalate` |
| **Attestation** | The signed record of a decision, as a claim / evidence / warrant triple |
| **Drift** | A divergence between the state the basis declares and the state observed |

**Vocabulary for tool protocols.** Where the executor calls tools through a protocol such as the
Model Context Protocol, an **action** is a tool name, a **resource** is a resource URI or the
target named in the tool's arguments, and the **enforcement point** sits where tool calls are
dispatched. Protocol-level authorization (for example OAuth scopes) says *which tools* a client may
reach. The envelope adds what scopes do not carry: bounds, expiry per change, prohibitions,
escalation and an attestation per call.

---

## 3. The envelope document

An envelope is a JSON document, readable by a machine and by an auditor. That double legibility is
deliberate: **the artifact the executor obeys is the same artifact the auditor examines.**

| Field | Required | What it is |
|---|---|---|
| `spec` | yes | The specification version: `grant-envelope/0.1` |
| `id` | yes | A unique identifier for this envelope |
| `executor` | yes | The identity the envelope authorizes. One executor per envelope |
| `basis` | no | The approved change it derives from: a reference and a digest |
| `grantors` | yes | `requester` and `approver`, distinct identities |
| `scope` | yes | The explicit inventory of resources the envelope may touch at all |
| `grants` | yes | The actions allowed, each with its resources, bounds and reversibility |
| `prohibitions` | yes | Actions that are never allowed under this envelope, even if a grant would match. MAY be empty, MUST be present |
| `validity` | yes | `not_before`, `not_after`, and who may revoke |
| `in_flight` | no | What happens to actions already started when validity ends. Default `complete` |
| `escalation` | yes | Where escalations go, how, and how long to wait |
| `signatures` | yes | Signatures over the canonical envelope, verifiable by a third party |

### 3.1 Grants

```json
{
  "action": "reprovision",
  "resources": ["node:01", "node:02", "node:03"],
  "when": "health-check-failed",
  "bounds": { "max_count": 2, "per": "P1D" },
  "reversibility": "irreversible",
  "compensation": "the node is rebuilt from the approved image; no data lives on it"
}
```

- `resources` MUST be a subset of `scope`.
- `when`, if present, names the condition under which the grant applies. An action outside its
  condition does not match the grant.
- `bounds` MAY combine a count per period, a maximum value, and time windows.
- `reversibility` is `reversible` or `irreversible`. ADR 0006, rule 3: the axis is reversibility,
  not risk. An `irreversible` grant MUST carry `compensation`, stating what answers for a mistake
  since nothing undoes it.

### 3.2 Prohibitions

A prohibition names an action, and optionally resources, that the envelope never allows:
`{ "action": "wipe-disk" }`. Prohibitions exist so that the most dangerous actions are named
explicitly rather than left to the absence of a grant, and so that a wider grant added later by
mistake still cannot reach them.

### 3.3 Canonical form and signatures

Signatures cover the envelope without its `signatures` field, serialized with the JSON
Canonicalization Scheme (RFC 8785). Each signature names its signer and role (`requester` or
`approver`). The envelope is valid only if the approver's signature verifies. The signing mechanism
is not fixed by this version; any scheme a third party can verify without trusting the enforcement
point conforms.

---

## 4. Invariants

A conforming implementation holds all of these. None is an optional refinement.

| # | Invariant |
|---|---|
| **I1** | **Deny by default.** An action that no grant matches is not allowed. |
| **I2** | **Prohibitions win.** A prohibited action is not allowed even when a grant matches it. |
| **I3** | **Segregation.** `requester` ≠ `approver`, and neither is the `executor`. An executor cannot grant itself. |
| **I4** | **No wider than the basis.** When a basis exists, every grant stays within what the basis declares: an envelope never authorizes a resource or action its approved change did not contemplate. |
| **I5** | **Bounds are part of the grant.** Exceeding a bound is not an exception to the grant; it is outside it. |
| **I6** | **Immutability.** A signed envelope never changes. Any change, including a wider bound or a longer validity, is a new envelope with new signatures. |
| **I7** | **Expiry.** No new action starts before `not_before`, after `not_after`, or after revocation. Actions already in flight follow `in_flight`. |
| **I8** | **Fail closed.** If the enforcement point cannot evaluate (it is down, cannot verify a signature, cannot read its counters), the action is denied. Its unavailability suspends autonomy; it never suspends control. |
| **I9** | **The enforcement point owns the state.** Counters, clocks and revocation lists live with the enforcement point, not with the executor. When clocks disagree, the enforcement point's clock is authoritative (ADR 0006, rule 7). |
| **I10** | **Never in the instructions.** An envelope expressed only as instructions to the executor (a system prompt, a README it reads) is not an envelope. It is enforced by absence or refusal, where the executor's reasoning cannot reach it. |
| **I11** | **Every decision is attested.** `allow`, `deny` and `escalate` alike (§8). |

---

## 5. Deciding an action

For each proposed action, the enforcement point evaluates, in this order, and stops at the first
step that decides:

| Step | Check | If it fails |
|---|---|---|
| 1 | The envelope's signatures verify | `deny` |
| 2 | Now is within `validity` and the envelope is not revoked | `escalate` |
| 3 | The action is not prohibited | `deny` and `escalate` |
| 4 | The resource is within `scope` | `escalate` |
| 5 | A grant matches the action, the resource and its `when` | `escalate` |
| 6 | The matching grant's bounds are not exceeded | `escalate` |
| — | All checks pass | `allow` |

**Absence first.** Where the enforcement point can shape what the executor sees (a tool list, a
credential, a dispatch table), actions not granted SHOULD be absent rather than refused. Refusal is
the fallback for bounds that can only be checked per call.

**Three outcomes and no waiting room.** There is no `pending`. An action that does not fit is not
queued for approval; it is refused, and the refusal becomes an escalation (§7).

---

## 6. Drift taxonomy

Drift is a divergence between the declared state and the observed state. The envelope decides what
the system may do about it. Each class has one response.

| Class | What was observed | Response |
|---|---|---|
| **D1 — Remediable** | A divergence for which a grant exists (a failed node, a crashed job) | Act within the grant, attest |
| **D2 — Remediable, bound exhausted** | Same, but the grant's bound is spent (the third failure of the day) | Do not act; escalate |
| **D3 — Unanticipated** | A divergence no grant covers | Do not act; escalate with context |
| **D4 — Prohibited remedy** | The only remedy is a prohibited action | Do not act; escalate as priority |
| **D5 — Unattributed change** | State changed with no attested decision behind it: someone acted around the enforcement point | Do not revert automatically; report as a **control failure**, not as drift |
| **D6 — Orphaned** | A divergence persists after the envelope expired or was revoked | Report; nothing acts until a new envelope exists |

D5 is the class that measures the enforcement point itself. A system that sees D5 often does not
have a drift problem; it has a bypass problem, and no envelope fixes a path that does not go
through the enforcement point.

---

## 7. Escalation

Escalation replaces approval. Its semantics:

1. **An escalation is a request for a new envelope**, not a request to approve one act. It carries
   the proposed action, the active envelope, the step of §5 that failed, and the observed state.
2. **Nothing acts while an escalation is open.** The action that triggered it stays denied.
3. **It has three endings, each attested:**
   - **Granted.** The grantors sign a new envelope. A one-off permission is an envelope with a
     single grant, `max_count: 1`, and a short validity.
   - **Refused.** A signed refusal. The action stays denied.
   - **Timed out.** After `escalation.timeout` with no answer, the outcome is refusal. Silence
     never grants.
4. **Escalation goes to people, not to the executor.** The executor may request, never resolve.

A growing rate of escalations is information, not failure: it says the envelopes are too narrow for
reality. A rate near zero may say they are too wide to be control. Both are measured.

---

## 8. Attestation

Every decision produces an attestation with three parts, following Toulmin's model of argument:

| Part | Content |
|---|---|
| **Claim** | What happened: executor, action, resource, decision, time |
| **Evidence** | What the decision was based on: the envelope `id` and digest, the observed state, the counter values |
| **Warrant** | **Why the evidence supports the claim**: which grant matched and which bounds held, or which step of §5 failed |

The warrant is what makes the record judgeable. A log says *the node was reprovisioned at 03:07*.
An attestation says *it was reprovisioned because grant 2 of envelope `e-7f3a` allows two
reprovisions per day on nodes 01–03 after a failed health check, this was the first today, and the
approver signed that envelope on 19 September.*

Attestations are signed by the enforcement point and chained: each carries the digest of the
previous one, so that a missing or altered record is detectable. They MAY be carried as in-toto
Statements with predicate type `https://macss.ccisne.dev/spec/grant-envelope/v0.1/decision`.

---

## 9. Failure modes this specification names

| Failure | Position |
|---|---|
| **Escalation storm**: envelopes are too narrow | Measured through the escalation rate (§7); it is the condition to watch, not to hide |
| **Envelope wider than intended** | I4 and review of the compiled envelope by the approver, who signs the envelope rather than only the change |
| **Enforcement point down** | I8: fail closed. The cost is lost autonomy; that cost defines its availability requirement |
| **Expiry mid-action** | `in_flight`: by default, what started finishes and nothing new begins |
| **Signing keys compromised** | Revocation is part of `validity` from the first version, not a later addition |
| **The enforcement point is bypassed** | Detected as D5. Prevented only by removing every credential that reaches the target without it |

---

## 10. Not in this version

- How envelopes are compiled from a basis and an organization's policy.
- A revocation protocol beyond naming who may revoke.
- Delegation chains (an envelope that authorizes signing narrower envelopes).
- Mapping to any specific control framework.

---

## 11. Examples

- [`examples/agent-refunds.json`](examples/agent-refunds.json): a support agent granted refunds up
  to a value, on its own tickets, in working hours.
- [`examples/node-remediation.json`](examples/node-remediation.json): a reconciler granted bounded
  remediation of failed servers, with the destructive action prohibited.

---

## References

- ADR 0005: complete context for the agent, accountability for the human.
- ADR 0006: autonomy is granted, not approved. This specification is its instrument.
- ADR 0010: complete information back to the human is what makes accountability scale.
- RFC 2119, RFC 8785 (JSON Canonicalization Scheme), JSON Schema 2020-12.
- S. Toulmin, *The Uses of Argument* (1958): claim, data, warrant.
