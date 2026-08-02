# Operational plan — the requisition produces the issue

- **Status:** proposed, pending approval
- **Repository:** `macss/macss` (`code/cli`)
- **Baseline:** `main` at `72d544c` (macss 0.3.2)
- **Analysis:** settled in `cacsi-dev/handbook` chapter 05 — *Un requerimiento, un issue*

---

## 1. Context

The CLI encodes a model the methodology no longer uses.

Today `macss specification new` scaffolds a requisition **and** a specification,
and `macss issue new` derives one or more issues **from** that specification —
each declaring, through `covers:`, which acceptance criteria it takes on. That
is a one-to-many relation: one specification, many issues.

The handbook now states the opposite, and resolves a contradiction it carried
for a long time (it said both *"un GitHub Issue = un requerimiento"* and *"se
descompone en Issues"*):

> **One requirement is one issue.** A requirement too large to deliver as a unit
> is split into smaller *requirements*, each with its own issue, specification
> and DoR.

And it changes when the issue exists: **the issue is born when the requisition
closes**, before the specification is written. That solves a real gap — until
then a requisition lived nowhere, it was an email.

This plan brings the CLI to that model.

## 2. What is settled

| # | Decision | Consequence |
|---|---|---|
| D1 | One requirement is one issue | `covers:` and `spec:` lose their reason to exist |
| D2 | **Two templates, different authors** | `requisition.md` is a form for the Product Owner; `specification.md` is QA's contract. They are **not** merged |
| D3 | The issue is the **projection** of both | It is generated, never hand-authored. The third document disappears |
| D4 | The issue is created early, updated later | `requisition publish` creates it; `specification publish` adds the contract |
| D5 | `repo` is dropped | `gh` infers it from the directory, like `gh pr list`. Optional `--repo` stays as an escape hatch |
| D6 | `issue.yaml` lives **with the requisition** | It has hand-editable fields (title, labels), so it is material, not CLI state |
| D7 | `.macss/state.yaml` holds CLI state | Renamed from `specification.yaml`, which now names the wrong thing |
| D8 | Language keywords come from **vocabulary assets** | Adding a language = one asset + one template, no Dart change |
| D9 | `publish` runs the module check **and** a size preflight | Different concerns, both belong there — see §6 |
| D10 | Business value: three questions to the PO, the observable signal from analysis | Keeps the form answerable — see §5 |

### On D2 — why the templates are not merged

`requisition.md` is a **form handed to the Product Owner**. Its metadata is
business metadata — system, project, requester, urgency — and it carries nothing
about the tool or the repository, because the person filling it is not an
engineer. `specification.md` is written by QA coordinating the PO and
development.

Merging them would hand the Product Owner a document that already contains QA's
sections, conflating *what was asked* with *what was agreed*.

What unifies is not the forms but **where the result persists**: both
materialize as the issue.

### On D6 — the requisition folder is self-contained

```text
.macss/state.yaml                      ← which requisition is active (CLI state)
docs/requisitions/<YYYYMMDD>-<slug>/
  ├── requisition.md                   ← the Product Owner writes this
  ├── specification.md                 ← QA writes this
  └── issue.yaml                       ← title, labels, issue number
```

Everything about one requirement lives together, reads together and moves
together. `.macss/` holds only what belongs to no requirement in particular.

That `publish` writes the issue number into `issue.yaml` commits nothing: the
folder is git-ignored, as is `.macss/`, and both entries are already managed by
`macss project create` and `macssGitignoreEntries`.

---

## 3. Command surface

| Today | After | Note |
|---|---|---|
| — | `macss requisition export-template` | Hand the blank form to the PO; render with `docmd` |
| `macss specification new <slug>` *(creates both files)* | `macss requisition new <slug>` | Creates `requisition.md` + `issue.yaml` + the active pointer |
| — | `macss requisition check` | Is the request complete? |
| — | `macss requisition publish` | `gh issue create`, body = the request |
| — | `macss specification export-template` | The blank contract template |
| `macss specification new <slug>` | `macss specification new` | **Behaviour change**: creates only `specification.md`, and requires an active requisition |
| `macss specification check` | `macss specification check` | Same name, gate rules change — see §4 |
| `macss issue publish <name>` | `macss specification publish` | `gh issue edit`, body = request + contract |
| `macss issue new <name>` | **removed** | The issue body is generated, not authored |
| — | `macss dor check` | The gate: composes both checks, adds its own |

`export-template` keeps a verb at the leaf, as `docs/architecture.md` requires —
the same rule that ruled out an `init` module.

---

## 4. The gate: from tracing to readiness

Two of the six current rules are tautologies under one-to-one and are removed:

| Rule | Fate |
|---|---|
| `SPEC_NO_ISSUE` — *"derive at least one issue"* | **removed** — the document *is* the issue |
| `SPEC_AC_NOT_TRACED` — *"every AC traces to an issue"* | **removed** — every AC is in this issue by definition |
| `SPEC_NO_COMMITMENT_DATE` | kept |
| `SPEC_NO_USER_STORY` | kept |
| `SPEC_STORY_MISSING_AC` | kept |
| `SPEC_SCOPE_INCOMPLETE` | kept |

The four survivors move to `specification check`. `requisition check` gets its
own rules over the form, and `dor check` composes both and adds what neither
owns:

```text
requisition check    → form:     mandatory fields, need and value, AS-IS/TO-BE, urgency
specification check  → contract: ISO date, ≥1 story with AC, explicit scope
dor check            → calls both, then:
                       · the issue is published (issue.yaml carries a number)
                       · dependencies identified
                       · test data available or planned
                       · the observable success signal is stated
```

The DoR-specific criteria are the **cross-cutting** ones: not about a document
being well formed, but about whether work can start. That is what justifies
three levels rather than one.

> Compared against industry practice, this DoR is **stronger** than the standard
> on testability — it requires planned tests whose feasibility development has
> confirmed, which no common checklist asks — and had **one gap**: nothing
> required the request to state its value. D10 closes it.

---

## 5. Business value without bureaucracy

The risk is real: a longer form is a form that does not get filled.

The four questions are not equal. **Three are business facts only the Product
Owner has**, each answerable in a sentence, and they go in `requisition.md`:

```markdown
## 1. Necesidad y valor

**¿Qué problema resuelve?**
**¿A quién afecta?**
**¿Qué pasa si no se hace?**
```

**The fourth is a skill, not a fact.** Turning *"how will we know it worked"*
into something observable is the same muscle as writing acceptance criteria, so
it emerges from analysis and lands in `specification.md`, agreed with the PO —
the same shape the acceptance criteria already follow.

No gate can judge prose. What defends against a pretty phrase is that QA has to
translate the stated value into an observable signal; **if it cannot be
translated, that reveals the value was vapour**. The check is the translation,
not the field.

---

## 6. Publishing: two different checks

`publish` runs the module's own check first — publishing an incomplete request
or a malformed contract has no purpose.

It also runs a **size preflight**, which deliberately does *not* live in the
gate:

- `check` validates **one document**; the issue body is the assembly of two, so
  neither check can see the total.
- 65,536 characters is a GitHub number, not a methodology criterion. Putting it
  in the DoR would tie the methodology to one vendor's limit.

So `publish` assembles the body, and fails before the network call naming which
document overflowed and by how much — rather than letting `gh` return a bare
422. (In practice the limit applies to the *gzipped* request, so real capacity
is higher; a specification with ten stories is around 10 KB.)

---

## 7. Language: one test suite, vocabulary as assets

Today the gate mixes two techniques for the same problem:

```dart
static const _includesHeadings = ['Includes', 'Incluye'];   // bilingual union
for (final keyword in const ['As a', 'I want', 'So that'])  // English only,
                                                            // embedded in the es template
```

The second is why `specification.template.es.md` carries `**As a (Como)**`:
English is kept inside the Spanish template so one matcher finds both. That
mixture is confusing for a Product Owner reading a Spanish form.

**Vocabulary moves to assets, keyed by the `macss:lang` directive the document
already declares:**

```yaml
# assets/vocabulary/es.yaml
story:
  role:    "Como"
  want:    "Quiero"
  benefit: "Para"
scope:
  includes: "Incluye"
  excludes: "NO incluye"
```

Adding a language becomes: one vocabulary file plus one template. No Dart
changes, and — because the tests **enumerate the vocabulary directory instead of
listing languages** — the new language enters the existing suite automatically.

Sections stay matched by leading number (`1.`, `2.`, …), which is already
language-independent and stays that way.

With this in place the Spanish template can drop the English entirely:
`AS-IS` → *Situación actual*, `TO-BE` → *Situación deseada*,
`Given/When/Then` → *Dado que / Cuando / Entonces*.

> Verified: the gate does **not** parse `AS-IS`, `TO-BE` or `Given/When/Then` —
> they appear only in a doc comment and an error message. Only the three story
> keywords are load-bearing.

---

## 8. Work, in TDD order

Each phase is red → green → commit, and each leaves the suite green.

**Phase 1 — Vocabulary, no behaviour change.**
Introduce `assets/vocabulary/{en,es}.yaml` and a loader; make the gate read
keywords from it instead of its constants. Tests enumerate the vocabulary
directory. Existing gate tests must pass untouched — this phase is a refactor,
and that is the proof.

**Phase 2 — Templates.**
Add *Necesidad y valor* to `requisition.md`; translate the non-coupled English
out of the Spanish templates; drop `spec:` and `covers:` from the issue
front-matter. Tests: the shipped templates parse under their own vocabulary.

**Phase 3 — `requisition` module.**
`export-template`, `new`, `check`. `new` writes `requisition.md`, `issue.yaml`
and `.macss/state.yaml`. Contract tests in both styles, as `create_test.dart`
does.

**Phase 4 — publish, create and update.**
`requisition publish` creates; `specification publish` updates. Body assembly
from one or both documents. Size preflight. `--plan` remains the default.
Injected `ProcessRunner`, as `issue publish` already uses, so no test touches
the network.

**Phase 5 — `specification` module.**
`export-template`, `new` (behaviour change: one file, requires an active
requisition), `check` with the four surviving rules.

**Phase 6 — `dor` module.**
`check` composing both module checks plus the cross-cutting criteria.

**Phase 7 — Removal and release.**
Delete `issue new` and the issue-as-code template. Rename
`.macss/specification.yaml` → `state.yaml`. Update the drift guards
(`help_command_test`, the TUI banner, `doctor`'s asset list), CHANGELOG,
version bump, docs and ADR.

---

## 9. Verification

**Automated**, from `code/cli/`:

```
dart pub get && dart analyze --fatal-infos && dart test
```

**Manual, end to end** against a compiled binary, in a temporary directory:

```
macss project create --path=.
macss requisition export-template          # the blank form for the PO
macss requisition new demo --lang es
# (fill requisition.md as the PO would)
macss requisition check                    # exit 0
macss requisition publish --plan           # preview
macss requisition publish --apply          # gh issue create → number in issue.yaml
macss specification new
# (fill specification.md)
macss specification check                  # exit 0
macss specification publish --apply        # gh issue edit → body = request + contract
macss dor check                            # exit 0
```

Plus the negative paths: `dor check` before publishing must fail naming the
missing issue; `specification new` without an active requisition must fail
naming that.

---

## 10. Breaking changes

| Change | Impact | Mitigation |
|---|---|---|
| `macss issue new` removed | Scripts calling it break | Documented in CHANGELOG; the body is generated now |
| `specification new` creates one file | Different output | Same name, new behaviour, documented |
| `.macss/specification.yaml` → `state.yaml` | In-flight requisitions lose the pointer | `--slug` resolves the folder without it, as today |
| Three-file requisitions | Old layout unreadable by the new commands | **Open** — see §11 |

Version: **0.4.0**.

## 11. Open items

1. **Migration of existing three-file requisitions.** `docs/requisitions/` is a
   git-ignored local workspace, so the options are: do nothing and document;
   have `check` detect the old layout and explain; or ship a `migrate` command.
   Undecided.
2. **Whether `requisition check` should also verify `issue.yaml` is well
   formed**, or leave that to `publish`.
