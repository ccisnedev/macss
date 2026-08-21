# Changelog

All notable changes to this project will be documented in this file.

The format loosely follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## [0.10.2]

### Changed

- **A command that has nothing to do now says why, not just that.** Four
  messages here were being computed and thrown away, because a plan that comes
  out empty never reaches `describe`. The caller was told `nothing would
  change` — a fact, with the actionable half removed.

  | Command | Now says |
  |---|---|
  | `upgrade`, already current | `Already on the latest version` |
  | `upgrade`, latest is a prerelease | `Latest release is a prerelease — skipping.` |
  | `skill clean`, nothing installed | `No supported assistant found in your home directory.` |
  | `requisition prune`, nothing finished | `Nothing to remove: no requisition is done or discarded.` |

  `upgrade` is the clearest case, because it has **two different nothings**.
  The second explains a decision the tool took on your behalf, and collapsing
  it into `nothing would change` hid that a choice had been made at all.
  `requisition prune` is the one most often read: finding nothing finished is
  the ordinary outcome of a prune.

  The reason now reaches `--plan` as well, where an empty plan had always been
  mute — that path never called `describe`, so this was never a regression,
  just a silence with no way to fill it.

- **`modular_cli_sdk` 0.5.0**, which is where the mechanism
  (`ExplainsNothingToDo`) comes from. It also stops `--apply` from asking for
  approval over a plan that changes nothing — which, with no terminal to
  answer, used to fail an invocation that had nothing to do.

### Fixed

- **A merge that does not raise the version no longer marks `main` red.** The
  release workflow's version check *said* "skipping release" and then exited
  `1`, so every ordinary merge — a refactor, a doc fix, a dependency bump —
  finished with a failed run. A red mark that appears when nothing is wrong is
  how a red mark stops meaning anything. It now sets `should_release=false` and
  the release jobs are skipped, which is what `inquiry`'s workflow already did.

## [0.10.1]

### Fixed

- **`macss upgrade` says what it is doing again.** 0.10.0 replaced the
  installation in silence: the rewrite that turned the command into steps
  dropped six `stderr` lines and nothing noticed, because nothing asserted
  them. Downloading several megabytes with no output reads as a hang.

  The plan already says what *will* happen — it did before this fix too. What
  was missing is the other thing, that it *is* happening, and no plan can
  stand in for it. Three lines now, on stderr so `--json` stays
  machine-readable:

  ```
  Downloading macss-windows-x64.zip (0.10.0 → 0.11.0)...
  Extracting into C:\Users\...\macss...
  Verifying installation...
  ```

  The three the old command printed *before* the download — current version,
  checking, latest available — are not back. The plan states all of it, with
  the asset and the URL, before anything is approved.

### Changed

- **`ReplaceInstallation` takes the binary it is replacing, and how to fetch
  the archive.** Both were reaching for globals: `Platform.resolvedExecutable`
  and a live `HttpClient`.

  The first mattered more than it looked. On Windows the step renames the
  running executable aside before overwriting it — and
  `Platform.resolvedExecutable` is `macss.exe` only when a compiled `macss.exe`
  is what runs. Under `dart test` it is the Dart VM, so a test that reached the
  default renamed the SDK's own `dart.exe` to `dart.exe.bak` and took the
  toolchain down with it. That happened, on the machine this was written on.

  The same trap is documented in `modular_cli_sdk`'s README, which is why
  `example/beside_executable.dart` exists there: under `dart run` a CLI that
  resolves paths against its own executable resolves them inside the Dart SDK.
  There the symptom is reading in the wrong place. Here it was writing.

  Fetching is now a `Downloader` function rather than an `HttpClient`, so the
  step knows nothing about HTTP and a test can stand in for the network without
  faking an interface it never uses.

- Six tests pin the commentary and the Windows rename, so neither can be lost
  the way the first one was

## [0.10.0]

The CLI moves to `modular_cli_sdk` 0.4.1, where a route is either a **query**
that reads and answers, or a **command** that changes something through steps
which say what they would do before anything runs — and are held to it.

**The command surface is unchanged.** Every invocation that worked before works
now. What changed is how the commands are built, and four things a user can see,
listed under *Changed*.

### Added

- **A plan names every step separately, and says what it cannot know yet.**
  `requisition publish` announces the issue it would create *and* declares that
  the number and URL are `known once this runs`; the step that writes the number
  into `state.yaml` reads it from the step that produced it rather than asking
  `gh` a second time. The same holds for the pull request in `delivery publish`
  and `verification publish`

- **Orderings that mattered are visible before they happen.**
  `delivery publish` is push → open → record: the push is first because
  `gh pr create` resolves the head on the remote and a branch it has never seen
  is not there to resolve; the record is last because a number written before
  `gh` returned would claim something the platform never received. Both were
  comments above consecutive statements. `uninstall` unsets PATH before
  scheduling the deletion, for the same kind of reason

- **Every step's report is checked against its own claim.** A step that
  announced `create` and did `keep` is named on stderr whatever the command
  chose to say — the broken promise is the framework's, and a reader must not
  have to take the command's word for it

### Changed

- **`--autoapprove` on its own is diagnosed as itself.** It used to fall through
  to "Choose --plan or --apply", which answers "choose one" to somebody who had
  chosen something — just not something that acts alone

- **A refused precondition reaches stderr as an error**, where it used to reach
  stdout as a result: an incomplete requisition, a body over GitHub's limit, a
  form that already exists, a delivery that fails its gate. Exit codes are
  unchanged

- **A plan file is written only inside a MACSS project.** Five commands are
  built to run where none exists — `requisition export-template`,
  `skill deploy`, `skill clean`, `upgrade`, `uninstall` — and `export-template`
  says so in its own contract: `--lang` is required there because *"this runs
  where no project need exist"*. Filing a plan would have answered that by
  creating `.macss/` in a directory whose owner asked for a blank form and
  nothing else. Outside a project, `--plan` prints the plan and files nothing

- **`--plan` on a document that already exists says `keep`.**
  `specification new`, `delivery new` and `verification new` used to
  short-circuit ahead of the convention, so asking what they would do to a
  requisition that already had the document said nothing at all

### Removed

- **`src/plan_apply.dart`.** `ChangeFlags`, `ChangeMode`, `Approver`,
  `ConsoleApprover`, `NoApproverAvailable`, `ChangeGate` and `ChangeDecision`
  moved into the SDK, which declares and applies the convention for every
  command. They were duplicated the moment it shipped them: 114 of the 190
  errors on the version bump were four names existing in two places. What
  survives is `src/plan_file.dart`, the one decision the SDK deliberately does
  not take — whether a plan is kept on disk, and where

- **The three ways this CLI previewed a change.** `skill deploy` threaded a
  `dryRun` boolean into `deploySkills`, which then ran the same traversal twice;
  `skill clean` wrote the preview loop and the removal loop out separately,
  character for character; `requisition new` asked `existsSync()` for the
  preview and asked again forty lines later for the work. All three worked, and
  nothing held any of them to anything

- **`message`, `planPath` and `blocked` from every command's `Output`.** They
  described the gate rather than the work, and modelling "nothing happened" in
  each command's DTO is how they got there

### Notes

- **`specification new` and `delivery new` are one command now.** Same input,
  same validation, same step, same idempotence — what differed was four
  strings. `verification new` is deliberately separate: it reads the frozen
  contract from the platform before the plan is built, refuses a requisition
  with no published issue, and its answer carries the criteria it listed
- 490 tests pass. The count is below the previous 502 because assertions about
  `--plan` and `--apply` were **deleted rather than rewritten**: the SDK owns
  that rule and tests it in one place instead of thirteen

## [0.9.0]

### Added
- **`macss requisition prune --plan` / `--apply`** — the workspace lets go of
  what is finished. Nothing removed a requisition, so the ratio of noise to
  signal only grew and the command whose purpose is to answer *"what is next?"*
  had stopped answering it.

  The criterion is local: the state the gates recorded, never a question put to
  the platform. That is not a shortcut — `dod` is the method's own definition of
  finished, and the merge only confirms the grant was honoured. It also
  expresses what no platform can: a requisition **discarded**, superseded or
  abandoned, which was never delivered and never will be.

  A folder nothing can read is never removed. "I cannot tell" and "it is
  finished" are different answers, and only one of them authorises destruction —
  so unreadable folders are named in the plan and left alone.

  It destroys with no `git restore` behind it, and what makes that safe is not
  the command's caution: after the Definition of Done nothing in the folder is
  unique. The request and the contract are the issue body, the delivery and the
  evidence are the pull-request body, and the diagnosis and the plan are
  comments on the issue. The working documents go with the rest on purpose — the
  code is what they became, and decisions worth keeping are in `adr/`.

  If it removes the active requisition it clears the pointer, rather than
  manufacturing the dangling state the listing exists to report.

- **`macss dod check`** — the Definition of Done, and the mirror of `dor check`.
  It composes the two stage gates rather than replacing them — the delivery
  judges the implementer's claim, the record judges the verifier's judgement —
  and adds what neither owns: that the work has a pull request. From here the
  pull-request body freezes, as the issue body freezes at the Definition of
  Ready.

  It reads the contract from the platform **once** and hands the same criteria
  to both gates. Composing means one question asked in one place; two gates each
  fetching their own copy could disagree about what the contract says.

  Review is not in it, and that is not an omission: ADR 0008 and the roadmap
  both decide it the same way — review fires on the pull request, on the
  platform, and joins when that integration exists.

- **`macss verification check` / `publish`** — the record is judged complete and
  then joins the pull request the delivery opened, the way the contract joins
  the issue the requisition opened. The body then reads as one thing: what was
  built, and that it holds.

  `check` asks three things and none of them is truth: every criterion of the
  contract is carried, none is left with the placeholder `new` wrote, and the
  conclusion exists. A criterion nobody judged is not the same as one that
  held, and a record must not read as if it were. Anything rejected or accepted
  with reservations counts as judged — a gate that only accepted agreement would
  push the walk towards recording agreement.

  `publish` pushes as a **safety net rather than a requirement**: verification
  produces no code, so "everything up to date" is the ordinary answer and is
  not a failure. What it covers is the walk that turned up a fix.

  `macss-verification` may now name the two commands of its own stage. Six
  entries stay barred from it — the delivery, the two gates either side, the
  harness, and the two stages before it. Naming the tool that performs your own
  stage is not the same as knowing about the stages around it, and instructing
  a stage without naming that tool is how a documented convention becomes one
  nobody follows.

- **`macss verification new`** — the record is opened before the walk starts,
  listing every criterion of the contract and judging none of them. Written
  afterwards a record is a reconstruction: what survives is what somebody
  remembers, which is the part that went smoothly.

  It reads the contract from the **platform**, not from disk. A verifier may
  hold no copy at all — `docs/requisitions/` is not versioned, so a local
  `specification.md` can be absent, stale, or edited since the body froze — and
  what is authoritative is the frozen issue body.

  It is the first scaffold in this CLI whose content depends on another
  document: the skeleton comes from a template in the project's language, and
  the criteria are generated from the contract by the same `acIds` the
  specification gate uses, so the two cannot disagree about what a criterion is
  called.

  It refuses rather than guessing in three cases: an issue body with no
  `macss:specification` marker, because the contract cannot be told apart from
  the request it follows; a contract that declares no criterion, which is a
  defect of the contract and not of the walk; and a requisition with no issue.
  And it never re-opens a record that exists — a walk already begun is exactly
  what re-scaffolding would throw away.

- **`macss delivery publish`** — the pull request appears as the consequence of
  publishing the delivery, the way the issue appears from publishing the
  requisition. There is no `macss pr` module for the same reason there is no
  `macss issue` one.

  It is the first command in this CLI that writes outside the machine by a route
  that is not `gh`: it pushes, because `gh pr create` resolves the head on the
  remote and a branch the remote has never seen is not there to resolve. So
  `--plan` names the push and performs neither it nor the `gh` call, and the
  gate runs before any of it — nothing leaves the machine on a red gate, and a
  push is the one step that cannot be taken back.

  The body points at the issue with a plain reference, never `Closes #N`. An
  issue may deliberately outlive the pull request that answered it, and
  auto-closing would fight a method that allows it.

  It records the pull request, the branches it was opened between, and the
  state, together. The branches are read from git at publish time rather than
  from the record: the record stores them afterwards, as the fact the transition
  produced.

- **`macss delivery new` / `check`** — the first stage of the pull-request side.

  `delivery.md` is the mirror of `requisition.md`: the first document of each
  pair reports, the second commits. The request states what was asked and nobody
  signs it; the delivery states what was built and nobody signs that either.
  What is signed is the verification.

  So it carries only what a verifier cannot derive from the frozen contract and
  the diff — which criterion is claimed where, what was deliberately not done,
  and how to reproduce it. Not what was built: the code says that. Not why:
  `adr/` says that, or nothing does. A delivery that argues its own quality is
  doing the verification's job from the one position that cannot.

  `check` judges shape and coverage, never truth, exactly as `requisition check`
  "judges presence, not quality". Three rules: `pr_title` parses as Conventional
  Commits — shape only, because a closed list of types would be the gate
  deciding what kinds of change a project may make; every criterion the contract
  declares is claimed with somewhere a reader can look; and the branch is not the
  one a pull request would merge into, which is the last gate before `gh pr
  create` would fail with all the work already done. When `origin/HEAD` is
  unset the branch rule warns instead of refusing — blocking on an unconfigured
  ref would stop the work for a reason that has nothing to do with the delivery.

  The criterion ids are generated in one place, `SpecificationGate.acIds`, so
  the contract, the delivery and the verification cannot disagree about what a
  criterion is called.

### Changed
- **`macss requisition list` reports the state and the pull request.**
  *(breaking for `--json`: `stage` becomes `state`, and `pr` joins `issue`.)*

  It used to answer "how far has this got?" from which documents were on disk,
  which could only ever report the five stages that write a file — `dor` and
  `dod` are gates and leave no artifact, so the listing said so in its own
  source. Now the gates record what they establish, and the listing reports the
  record. Deriving it a second way would be a second answer.

  The pull request is shown beside the issue **before** anything acts on it. It
  is the fact `prune` will decide by, and a destructive command whose criterion
  has never been displayed is one nobody can audit before running it (ADR 0010).

- **`issue.yaml` → `state.yaml`, the requisition's lifecycle record.**
  *(breaking, no fallback)* The old file held the title, the labels and the
  issue number: everything the issue needed, and nothing about what became of
  the requirement. That is why nothing could ever decide a requisition was
  finished, and why the workspace only grew.

  The record adds the state — `opened`, `published`, `specified`, `ready`,
  `delivered`, `verified`, `done`, `discarded` — and the handles each transition
  produced. Two titles, not one: the issue's, in the project's language, and the
  pull request's, which is a commit message and therefore English and
  Conventional Commits in every project.

  A transition writes the state and the fact it rests on together, so a record
  cannot claim to be published while nothing names the issue. A state outside
  the list reads as no record at all — the same answer as a missing file,
  because neither is "not finished yet", and `macss requisition list` shows both
  as unreadable rather than leaving them out.

  Existing workspaces have no `state.yaml` and every command will say so. There
  is no migration: `docs/requisitions/` is not versioned, and a compatibility
  path for a file nobody outside this repository has written would be legacy
  code on purpose.

- **`macss dor check` records that the requisition is ready.** It writes one
  word the gate has just proved, and still takes neither `--plan` nor `--apply`
  — a deliberate exception to ADR 0007, because a gate that must be told which
  of the two it is doing stops being runnable as a gate. A gate that does not
  pass writes nothing, and a passing gate never moves the state backwards.
- **`.macss/state.yaml` → `.macss/active_requisition.yaml`.** *(breaking, no
  fallback)* The file holds `slug`, `path` and `created`: it says **which**
  requisition is being worked on, which is a pointer and not a state. It was
  already renamed once for this reason — `.macss/specification.yaml` →
  `.macss/state.yaml`, *"the old name said something else"* — and that rename
  fixed the wrong half. The name cost nothing while nothing else in the project
  held a state; a requisition that records its own is what makes it a second
  answer to a different question.

  The old file is not read. It is git-ignored and local, so there is nothing to
  migrate and nothing to lose — but whoever upgrades stops having an active
  requisition, with no indication why. `macss requisition list` says so, and
  `macss requisition activate <slug> --apply` restores it in one command.

## [0.8.1]

### Changed
- **`macss-specification` rewritten.** The stage it covers was one imperative —
  *"Fill `specification.md`: the committed delivery date, user stories each
  carrying at least one Given-When-Then acceptance criterion…"* — one sentence,
  addressed to one person, producing everything at once. That is the corpus the
  method exists to prevent, prescribed by the method itself.

  Measured before rewriting: of the twelve concepts the new contract requires,
  **ten appeared zero times** — `authorize`, `inventory`, `one at a time`,
  `objectively`, `contradict`, `means to check` among them. The Product Owner
  appeared three times and never as somebody who authorizes: always as a source
  who sends, said, is transcribed. The person bound by the contract had no role
  in producing it.

  It now names **two agents**, and only one of them authorizes. The other may be
  a human or not: what defines it is not what it is but that it authorizes and
  answers for it afterwards.

  What it adds: the inventory of every source and repository, including what
  could not be opened and why, and an inventory that never closes; the complete
  list of stories as a stage of its own, iterated and closed before any
  criterion; criteria proposed as a list per story and then authorized **one at
  a time**, written into the contract at the moment each is decided; the two
  conditions a criterion must meet — objectively checkable, and compared against
  those already agreed, with any collision exposed rather than resolved; the
  means to check every claim, given whether or not anyone intends to use them;
  and what to do when a requirement cannot be specified at all.

  Built by using it on itself: twenty-six criteria authorized one at a time, of
  which the authorizing agent changed six while they were being written and
  discarded two.

- **The skill no longer tells anyone to split a request by its size.** The
  sentence *"if a request is too large to deliver as a unit, split the request
  into smaller ones"* is retired, and a test keeps it retired — a sentence that
  looks lost gets restored. Size depends on how busy the team is, which the
  method has no access to; splitting is a business decision. The method now has
  no opinion on how much a requisition covers.

### Added
- **A guard over the specification method**, the same shape as the one #42 built
  for verification: it pins the concepts the contract turns on and fails naming
  the criterion each absence would break. Seen failing on the version that
  shipped before this one, which was missing six of them.

## [0.8.0]

### Added
- **`macss-verification`** — the fifth lifecycle skill, and the one covering the
  stage where the human signs. The lifecycle was served up to the end of
  implementation and then stopped, exactly where accountability begins.

  It needs three things and knows nothing else: the acceptance criteria, the
  delivered change, and a human present. Where those come from and what happens
  to the work afterwards belong to whoever invokes it — so it works in a project
  with no requisitions, no issues, no pull requests and no gates.

  It teaches obligations rather than supplying a template, because sameness is
  the negative signal: verifications resemble each other only when a form is
  being filled instead of the work being done.

  **One criterion at a time**, with the human's judgement before the next.
  Claim, evidence and warrant stated separately. **Every question explicit** —
  what the criterion asked, what was checked, what was *not* checked and why it
  is out of reach, and the decision at stake as alternatives that are different
  acts. Never "does the reasoning hold?": that has an answer which depends on
  fatigue and trust, produces "yes, go ahead", and removes the accountability
  the stage exists to create.

  **When a criterion does not hold it says which of three things failed** — the
  work, the approach, or the criterion itself — with the evidence for that
  reading, and then **stops**. Where the work goes next is decided by whoever
  answers for the requirement. Offering the route is how a verdict quietly
  becomes a plan nobody chose.

  **It does not require the verifier to be someone other than the implementer.**
  One person can be requester, author of the criteria, implementer and signer.
  What makes it a verification is not who conducts it but that every criterion
  is faced one at a time, with reproducible evidence, and judged by someone who
  answers for the judgement.

  Written from five verifications conducted by hand — four in this repository
  (#21, #31, #24, #39) and one in a repository with none of this machinery.
  Every obligation is there because one of them needed it, including the last:
  the rule about explicit questions was found by asking a vague one and being
  corrected mid-walk.

- **The method is checked for what it must not say.** Six couplings —
  `delivery.md`, the pull request body, the Definition of Ready and Done, the
  state machine, the `delivery` module — are asserted absent, with the term and
  its line named when one reappears. A coupling is a word, and a word is exactly
  what goes back in quietly six months later, reading perfectly.

- **A skill that ships but that `doctor` does not check fails the build.** Added
  once during #34, lost when that branch was abandoned, and the hole reopened
  immediately: the skill shipped again, every suite stayed green again, nothing
  noticed. Recovered and now recording how it was lost — a guard living only in
  the branch it was written for dies with it.

### Known limit
- The skill teaches the practice; it does not enforce it. Nothing compels a walk
  criterion by criterion, and nothing stops an agent writing a conclusion it was
  told not to write. That has to come from the harness that runs it. Stated so
  the gap is known rather than assumed closed.

## [0.7.1]

Every invocation this CLI puts in front of somebody is now one the CLI accepts,
and a check asks the CLI rather than reading the message. Seventeen of the
thirty-one dictated invocations were refused by the binary that printed them.

The rule had already failed three times, each through a message that reads
perfectly: `project check` dictating `macss project adopt --plan` before that
flag existed — the defect this whole method started from — the banner dictating
`macss upgrade` after ADR 0007 made the choice mandatory, and the same
`project adopt` line again once 0.7.0 made `--lang` required. Reading is what
failed, so nothing in the check reads.

### Fixed
- **`macss issue publish` named a command that has never existed.** `doctor`
  reported it as what `gh` is needed for; the module is `requisition`. A test
  asserted the wrong name for as long as the string existed.

- **`macss project adopt --plan` and `--apply` were broken by 0.7.0.** Both
  carry the flag ADR 0007 requires and both were refused, because `--lang`
  became required and the two messages naming the command were not revisited.
  They now carry it. The `project check` one is the sentence this method was
  founded on, corrected for the second time in four days, for a different
  reason each time.

- **Fourteen messages named a changing command without saying which of planning
  or applying was meant** — `macss upgrade` in five places, `requisition new` in
  six, plus `requisition activate`, `specification new` twice. Each now says.

- **`macss specification new <slug>` passed a bare argument that command does
  not take**; it reads `--slug <slug>`.

### Added
- **A check that every dictated invocation is one the CLI accepts**, over the
  messages this CLI prints and over the skills it ships to agents. It asks the
  catalogue the CLI publishes — the route exists, the options are declared,
  nothing required is missing, and a command that changes something has been
  told which. Whether a command changes anything is **derived** from whether it
  declares `--plan`, never from a list kept by hand.

  Nothing is registered. A registry would be a second list to keep in step, and
  would leave a raw string added tomorrow unguarded — the one thing the
  requirement asks to prevent. The check reads what is actually in the source,
  so a new message is covered because it exists.

  It also pins how many invocations it *found*. A check that reports only
  violations passes loudest when it has stopped looking.

## [0.7.0]

A project says which language its documents are written in **once**, in
`.macss/config.yaml`, and every document derives from that. The setting used to
be a flag on each command: `requisition new --lang es`, then `specification new`
inheriting it from the requisition's `issue.yaml`, with `en` waiting as a
default wherever the chain broke. A setting passed per invocation is one that
can differ per invocation, and a project that answers differently on Tuesday
does not have an answer. ADR 0009 — a default may derive, but never invent — is
what this release applies to language.

### Added
- **`macss requisition list`** — every requisition in the project, with the
  active one marked, how far each has got, and the issue carrying it. Until now
  the only way to see what existed was to list `docs/requisitions/` and read
  folder names, which said nothing else.

  It reads what is on disk and does not run the stage gates: a row says "has a
  contract", not "the contract passes". Running three gates per row would be
  slow and could fail for reasons that have nothing to do with listing. It also
  shows a pointer aimed at a folder that is gone, rather than omitting it — a
  listing that hides a broken state is how it becomes trusted and wrong.

- **`macss requisition activate <slug>`** — choose the requisition the following
  commands act on. This was a hand edit of `.macss/state.yaml`, keeping two keys
  consistent with each other and with a folder name, checked by nothing. It was
  the only unguarded operation in a CLI that will not even choose between
  `--plan` and `--apply` for you, and it now follows that convention like
  everything else that writes.

  The name comes from the vocabulary already in the code: the pointer records
  the **active** requisition. `set` would not say what is being set, and git's
  `checkout` carries a meaning that does not apply.

### Fixed
- **A parameter the command refuses to run without is now declared required**,
  instead of being enforced in prose while `help --json` reported
  `"required": false`. That covers `--lang` on `project create`, `project adopt`
  and `requisition export-template`, and `--path` on `project create`.

  The catalogue is what a machine reads to learn how to call this CLI, and the
  reader who believed it — an agent composing an invocation — is exactly the
  reader it exists for. The refusal message becomes the SDK's
  (`missing required option --lang`) and the explanation moves into the
  parameter's description, which the same output prints and which `--help`
  reaches without anyone having to get it wrong first.

  Found while verifying #24 criterion by criterion, in a JSON printed as
  evidence for something else.

### Changed — BREAKING
- **`--lang` is gone from `requisition new` and `specification new`.** Both
  derive the language from `.macss/config.yaml`. Scripts passing the flag will
  fail with `unknown option --lang`; the language moves to the project, once.

  `specification new` also stops inheriting from the requisition's `issue.yaml`.
  Inheriting was the right instinct applied one hop at a time — it made the
  requisition an authority on a question that was never its own, and left the
  answer to be re-derived at every hop.

  Neither `issue.yaml` nor `.macss/state.yaml` carries a `lang:` key any more.
  A copy of the declaration is a second answer waiting to disagree with the
  first, and two answers is none. Existing files keep the key; nothing reads it.

- **`project create` and `project adopt` require `--lang <en|es>`.** A project
  declares the language of its documents at the moment that choice is made, by
  the person making it. There is no default: English is not a neutral choice,
  it is a guess about who will read the documents.

- **`specification export-template` is removed.** Of the two documents, only the
  requisition is handed to somebody outside the team — it is this method's issue
  template, and a Product Owner may prefer filling one directly. The contract is
  written by whoever holds the pen, on top of a request that already exists; a
  blank one is a form for work nobody outside is doing.

  `requisition export-template` survives **and is the one command that still
  takes `--lang`, now required**: it writes at a path that need not be a MACSS
  project, so there is nothing to derive from. Not an exception to the rule —
  the reason the rule has one.

- **A project that has not declared a language is stopped, not assumed to be
  English.** `requisition new` and `specification new` refuse and name the way
  out: `macss project adopt --lang <en|es> --apply`. **This includes every
  project created before this release**, the MACSS repository itself among them.
  Adopting is a one-line change and the command reports it in its plan first.

- **An ambiguous `--slug` is refused instead of resolved.** Two requisitions can
  answer to one slug: the date prefix makes folder *names* unique, not slugs.
  The resolver used to sort the matches and return the newest, silently. That is
  a default that invents a decision, which ADR 0009 forbids.

  It now resolves to nothing and the command reports both candidates. This
  reaches **every command that takes `--slug`** — `requisition check`,
  `requisition publish`, `specification new`, `specification check`,
  `specification publish` and `dor check` — none of which this change is named
  after. Where they used to proceed on a guess, they now refuse and name the
  candidates.

  A test asserted the old behaviour explicitly: *"multiple dated matches →
  newest (lexically last) wins"*. The suite was defending the defect, which is
  the second time that has happened in this cycle.

- **`.macss/` now ignores itself, and the project root stops hiding it.** A
  `--plan` in a project that had never opened a requisition created the
  workspace with nothing ignoring it: only `requisition new` knew about the
  ignore rule. The rule now lives inside the directory it governs, written
  wherever the workspace is created, so both paths into it — the active-
  requisition pointer and the plan files — find it already ignoring itself.

  It is an **allowlist**: everything ignored, exceptions named. The two designs
  fail differently. A denylist forgets in silence — anything MACSS invents there
  later is committed until somebody remembers to add it. An allowlist forgets in
  the open: somebody clones, a file is missing, it is noticed. `!.gitignore` is
  part of it, or the file that makes every other rule work is never committed.

  **`.macss/` is removed from the project root's `.gitignore`**, and `project
  adopt` retires it from projects that already carry it. That is not tidying:
  git does not descend into an excluded directory, so while the root excluded
  `.macss/` the inner rule was dead letter and nothing there could ever be
  versioned. Verified against real git rather than by reading the file back.

  **`adopt` removes something for the first time.** ADR 0004 said it never
  deletes, and that stands for anything the project wrote — the licence here is
  the one `skill deploy` already uses to prune its own namespace: an entry under
  the MACSS header is machine-written output, not a user edit. Nothing outside
  that header is touched, and the retirement appears in the plan like every
  other change.

### Changed
- **An incomplete invocation now says so, instead of claiming the command does
  not exist.** `macss project` answered `unknown command 'project'` followed by
  the whole catalogue; the name was real, and what was missing was the action.
  It now names the completions and only those:

  ```
  ❯ macss project
  Error: 'project' is not a complete command.

  Commands:
    project create  Scaffold a new MACSS project
    project check   Diagnose a project against the MACSS canon …
  ```

  The fix is `modular_cli_sdk` 0.3.4 and the constraint moves with it. Nothing
  in this CLI changed: the SDK asks its catalogue whether what was typed
  continues into a registered route, which also covers `macss api graphql` —
  not a module, but the first segment of `api graphql compile`.

## [0.6.0]

A breaking release on a minor bump: the project is still in the `0.x` series,
where the leading zero is the signal that the interface is not yet settled.

ADR 0004 named a `--plan` / `--apply` convention. Only `--apply` was ever built,
with the absence of it standing in for the plan — so `project check`, the
specification skill and the book all dictated `macss … --plan`, and every one of
those invocations failed with `unknown option --plan`. The documents were right
about what MACSS wanted; the binary had never caught up. ADR 0007 supersedes the
old convention and this release implements it.

### Changed — BREAKING
- **Every command that changes state now requires `--plan` or `--apply`.**
  Neither is a default and a bare invocation is a usage error. That covers
  `project create`, `project adopt`, `requisition new`,
  `requisition export-template`, `requisition publish`, `specification new`,
  `specification export-template`, `specification publish`, `skill deploy`,
  `skill clean`, `api graphql compile`, `upgrade` and `uninstall`. Read-only
  commands — `check` in every module, `doctor`, `version`, `dor check`,
  `skill list` — take neither and reject both.

  Previously the absence of `--apply` meant "preview". That made not-writing the
  outcome of forgetting a flag, so the safe path and the writing path were told
  apart by an omission and the invocation recorded neither. Every bare
  `macss project adopt` and `macss requisition publish` in a script will now
  fail, loudly and with the two ways out named.

- **`--plan` writes a plan file** under `.macss/plans/`, rather than printing a
  preview that dies with the terminal. A plan can be attached to an issue,
  diffed against a later run, or read by someone who was not at the keyboard —
  which is what MACSS asks of every other artifact it produces. Plans are
  written where the command was **invoked**, never inside the directory it
  targets: writing into the target would itself be a change, and for
  `project create` the target is what the command would bring into existence.

- **`--apply` shows the plan and asks before writing.** Declining changes
  nothing and exits non-zero. The plan it shows and the plan `--plan` writes are
  the same computation rendered once, so they cannot drift.

- **`--apply --autoapprove` applies without asking**, for agents and CI. When
  `--apply` finds no terminal to ask from it refuses and names the flag, rather
  than blocking on a read that will never return. `--yes` was rejected as the
  name: it answers a prompt without saying what is being agreed to, and the flag
  is not about the prompt — it transfers the approval from a human at the
  keyboard to whoever wrote the invocation.

- **The banner's quickstart now reads `macss project create --path=my-project
  --apply`.** A newcomer's first command is where the convention is learned.

### Changed
- **The specification skill instructs `--apply --autoapprove`** wherever it
  applies changes. A skill runs with nobody at the keyboard; a bare `--apply`
  would strand it on a prompt.

- **The guard on skills now checks flags, not just commands.** It stripped them,
  and the comment explaining why used `macss requisition publish --plan` as its
  example — the exact invocation that was broken. It passed for two releases
  over a skill telling models to type a flag the CLI rejected. It now also fails
  a skill that names `--apply` without `--autoapprove`.

- **The analyst may fill the requisition; the Product Owner remains its
  author.** The methodology said "Do not fill it for him", and the request
  arrives by email or in a meeting from someone who will not then sit down to a
  form — so the rule was broken on every requisition, including the ones that
  produced this release. It is replaced by what it was actually protecting:
  transcribe what he said, trace every line to a source, and ask him rather than
  filling a gap yourself. The `requisition` module's descriptions and messages
  no longer assume the form is handed over to be typed by him, and its gate is
  stated as what it always checked — whether every section is answered, not who
  answered it.

### Fixed
- **Approval no longer crashes where a terminal is claimed but unreadable.**
  `--apply` with stdout piped exited 255 with `StdinException: Error getting
  terminal line mode` on Windows: `stdin.hasTerminal` reported a terminal and
  the read then failed. Anything that stops an answer from arriving now produces
  the same refusal, so a command that changed nothing cannot present itself as a
  crash.

- **Republishing an issue no longer fails when the requisition declares
  labels.** `publish` sent `--label` to both `gh issue create` and `gh issue
  edit`, but only `create` accepts it — `edit` takes `--add-label`. The create
  path worked, so the break only surfaced on the second publish, which is
  exactly when `specification publish` adds the contract to the issue. `edit`
  now uses `--add-label`, which also leaves labels added by hand on GitHub
  alone. Nothing covered `plannedArgs`; both label paths are now tested.

## [0.5.0]

The skills are what a model actually executes. They had drifted from the CLI —
`macss-specification` was instructing `macss issue new` and `macss issue
publish`, removed in 0.4.0 — and nothing in the suite connected the two.

### Changed — BREAKING
- **`macss create` is removed.** It shipped deprecated in 0.3.0 as an alias of
  `macss project create`. Two names for one command left the grammar ambiguous
  about which noun owns scaffolding, which is the one thing `project` exists to
  settle.

### Changed
- **`macss-specification` is rewritten** for the one-to-one model. It now walks
  the whole stage — `requisition new` through `dor check` — instead of the
  middle of it, and states the two rules the commands cannot enforce: the
  Product Owner writes his own request, and the issue body freezes at DoR.
- **`macss-analyze` and `macss-plan` publish their output on the issue.** The
  diagnosis and the plan used to live in the model's session, which ends. They
  are now comments below the frozen body: the body is what was agreed, the
  comments are how the work unfolded.
- **`macss-execute` closes the chain** by opening the PR against the issue that
  carries the request, the contract, the diagnosis and the plan.

### Added
- **`skill_commands_test`**: every `macss <…>` a skill names is cross-checked
  against `help --json`, the CLI's own catalogue. A skill that instructs a
  command the CLI does not accept now fails the suite — the drift guard
  `help_command_test` gives the catalogue, aimed at the skills.
- The same guard for the **banner**, which is hand-maintained and advertised
  `issue` until someone edited it by hand. Every command it names must be a
  route the CLI serves, and it must name every lifecycle stage.

### Fixed
- `project_create_test` registered its own root-level `create` route rather than
  the module that ships. It exercised a contract no user could reach.
- `tui_test` asserted the banner `contains('create')`, which passed on the word
  appearing in the Quickstart line rather than on any advertised command — and
  kept passing after `create` was gone.

## [0.4.0]

The CLI now follows the model the methodology actually uses: **one requirement
is one issue**, and the issue is where the request and its contract persist.

### Changed — BREAKING
- **`macss requisition`** is the new stage module: `export-template` writes the
  blank form for the Product Owner, `new` opens the requisition, `check` asks
  whether he filled it, and `publish` creates the issue carrying the request.
- **`macss specification new` creates only `specification.md`**, and requires an
  open requisition. It used to create both documents, which collapsed a real
  distinction: the requisition is a form the business fills, the specification
  is QA's contract — different authors, different moments.
- **`macss specification publish`** adds the contract to the issue the
  requisition created, so the body reads request first, contract second.
- **`macss issue new` and `macss issue publish` are removed.** The issue body is
  assembled from the two documents rather than hand-authored, which is what
  made a third document — repeating their context and scope — unnecessary.
- **`.macss/specification.yaml` → `.macss/state.yaml`.** It records which
  requisition is active; the old name said something else.

### Added
- **`macss dor check`** — the Definition of Ready. It composes the stage checks
  and adds what neither owns: that the requirement has a home. Until the issue
  exists there is nothing to pick up, reference from a branch, or freeze.
- The requisition asks for **value**: what problem this solves, who it affects,
  what happens if it is not done. Three questions, one sentence each, all of
  them facts only the requester has. The fourth — how we will know it worked —
  lands in the specification, because turning value into something observable
  is analysis, not form-filling.
- **`assets/vocabulary/<lang>.yaml`.** The gate's keywords are assets now, so
  adding a language is one file plus its templates: no code change, and no new
  tests, because the suite enumerates the directory.

### Removed
- `SPEC_NO_ISSUE` and `SPEC_AC_NOT_TRACED`. Both were artefacts of
  one-specification-many-issues. Under one-requirement-one-issue they are
  tautologies: the document *is* the issue, and every acceptance criterion in it
  is covered by definition.
- `covers:` and `spec:` from the issue front-matter, and `repo` from the issue
  metadata — `gh` infers the repository from the directory, the way `gh pr list`
  does.

### Fixed
- The Spanish specification template no longer embeds English
  (`**As a (Como)**`). A Product Owner reading a Spanish form saw two languages
  mixed for no reason he could see.

## [0.3.2]

### Fixed
- **The banner's Quickstart advertised a command that fails.** It printed
  `macss create my-project` — a positional argument the CLI rejects (ADR 0002
  chose explicit flags), on the alias deprecated in 0.3.0. The first command a
  new user was told to run exited 7. It is now
  `macss project create --path=my-project`.

  The guard that should have caught it asserted the banner *contained* the
  string `macss create`, which a broken command satisfies. The test now runs
  the advertised command through the CLI and asserts it scaffolds a project,
  so a quickstart that stops working fails the build.

## [0.3.1]

### Fixed
- **`macss skill deploy` could add but never retire.** A skill dropped from a
  release survived in the host forever as a frozen copy nothing would ever
  update again. Deploy now removes skills in the `macss-` namespace that MACSS
  no longer ships, reporting each one.

  Scoped by prefix rather than a hand-maintained list of retirements: the
  `macss-` namespace is ours, so anything under it we do not ship is ours to
  remove — self-maintaining for any future rename or drop. Everything else in
  the directory is left alone, including another tool's skills.

## [0.3.0]

The lifecycle stages have a module surface, and the canon has a verifier.

### Added
- **`macss project`** — a project's conformance to the canon, at three moments.
  `project create` scaffolds one, `project check` diagnoses an existing one, and
  `project adopt` retrofits a project that predates MACSS (`--plan` previews,
  `--apply` writes). All three share one definition of the canon, so they cannot
  disagree about what a MACSS project is.
- `macss doctor` gains an external toolchain preflight: `git`, `gh`, `pwsh`,
  `dotnet`, `sqlpackage`, `docker`, `flutter` — each with what it is needed for
  and how to install it. Presence is a PATH lookup, so `doctor` stays instant.
- A third check status, `warning`, for what needs human judgement rather than a
  fix. It never fails a command.
- `CHANGELOG.md` is now part of the scaffold. The canon in
  `code/book/src/project-structure.md` always required it; `create` never
  produced it, and nothing detected the gap.

### Changed
- **`macss create` is deprecated** in favour of `macss project create`. It keeps
  working for one minor version. `create` is the entry point to the whole
  methodology but was a bare root-level command; the CLI grammar reserves
  modules for nouns and verbs for leaf actions, so it belongs under `project`
  beside the commands that verify what it stamps.
- The implementation skills — `macss-analyze`, `macss-plan`, `macss-execute` —
  are self-contained. They previously opened by invoking `iq`, which gave MACSS
  a runtime dependency on a second CLI. They now teach the method on their own,
  sourced from the engineering handbook.

## [0.2.0]

MACSS now owns the software lifecycle it defines. The specification and issue
stages, plus the skills for every stage, move here from the `inquiry` CLI, which
goes back to being the state machine for the implementation stage alone.

### Added
- `macss specification new <slug>` scaffolds a requisition workspace under
  `docs/requisitions/<YYYYMMDD>-<slug>/` and records it as the active
  requisition, so later commands need no slug. `--lang en|es`.
- `macss specification check` runs the `specification_ready` gate over the active
  requisition.
- `macss issue new <name>` scaffolds an "issue as code" file, inheriting the
  specification's language; `macss issue publish <name>` turns it into a GitHub
  issue via `gh`, previewing with `--plan` before `--apply`.
- `macss skill deploy` installs the four lifecycle skills
  (`macss-specification`, `macss-analyze`, `macss-plan`, `macss-execute`) into
  the skills directory of every supported assistant found in your home
  directory. `--host claude|opencode` targets one, whether or not it looks
  installed, so a fresh setup can be primed. Skills are installed once per
  machine, not per repository. `macss skill list` and `macss skill clean`
  complete the module.
- `Assets.listDirectory()`, sorted so deployment order is identical on every
  platform.

### Changed
- The scaffolded `.gitignore` now ignores `.macss/` and `docs/requisitions/`.
- `macss doctor` verifies the artifact templates and the shipped skills, not just
  the project templates.
- Unlike `create`, `skill deploy` refreshes a skill whose content changed:
  `.skills/` is reproducible machine output, so a stale file left behind by an
  older CLI is a defect, not a user edit.

### Migration
- The active-requisition pointer moved from `.inquiry/specification.yaml` to
  `.macss/specification.yaml`. A requisition in flight still works without any
  manual step — pass `--slug <slug>`, which resolves the folder directly and
  ignores the pointer. Move the file only to restore the convenience of an
  active requisition that the commands pick up on their own.
- The on-disk format tokens are now namespaced to MACSS: templates emit
  `macss:lang` and `kind: macss-issue`. Specifications already written with
  `iq:lang` keep resolving their language, so existing requisitions still work.

## [0.1.0]

### Changed
- Migrated the CLI to `modular_cli_sdk` 0.3.3 and `cli_router` 0.1.0.
- Every command declares its parameter contract, so unknown flags are rejected
  (exit 7) instead of being silently ignored.
- Help is rendered from the command catalog by the SDK; the hand-written `help`
  command was removed so help can no longer drift from the registered commands.
  `<command> --help` shows the command's declared contract.
- `macss create` now scaffolds `code/{db,api,app,infra}` with a README anchor per
  module — the presentation layer is `app` (renamed from `ui`) — so the structure
  survives the first commit and each module documents its allowed dependencies.
- `modular_api` and `modular_api_sqlserver` are consumed from published pub.dev
  versions instead of local paths.

### Removed
- Dead GraphQL compile help path (`helpRequested` flag and hand-written help
  text), superseded by the SDK-rendered contract.

## [0.0.3]

### Added
- `macss create` now generates `README.md` from template
- `macss create` now generates `.gitignore` with common exclusions
- `macss create` now generates `.gitattributes` for cross-platform line endings (LF default)

## [0.0.2]

### Changed
- `macss create` now uses `--path` flag instead of positional argument
  - Usage: `macss create --path=.` or `macss create -p <dir>`

## [0.0.1]

### Added
- `macss` — TUI banner with version, commands and alias
- `macss create <path>` — scaffold MACSS project structure from templates
- `macss doctor` — verify local installation and assets integrity
- `macss upgrade` — download and install latest release from GitHub Releases
- `macss uninstall` — remove MACSS CLI from the system
- `macss version` — print current CLI version
- CI matrix (Windows + Linux)
- Release workflow with binary + assets packaging
