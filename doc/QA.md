# Quality assurance

How a change is reviewed before submit.
The reviewer is usually checking someone else's work, so review asks
whether the change achieves what was intended, not only whether it
runs.
Roles are defined in [CONTRIBUTE.md](CONTRIBUTE.md).

## Premise

A gated, progressive hunt before submit.
The green suite already proves mechanical correctness, so review only
chases what tests cannot catch: a misread spec, a missing required
thing, a false claim, a latent trap.
Grade against the approved plan, not the spec, starting from the
author's summary before reading the repository.

## The floor

`shellcheck` clean and the `bats` suite green, through `just check`.
These are preconditions for review, not rungs in it.
A change arrives with both or it is not ready.

## Secret safety

marcustack holds credentials.
The rules in CONTRIBUTE.md under Security apply to every command a
review proposes.
Review adds:

- Assert against exit codes, HTTP status, and file presence.
  - Never against a credential value.
- Proposed commands stay short enough to read in full before running.
- Nothing is executed from a file the maintainer has not read.

The last two do the work.
The relay protects the maintainer only while he can see exactly what
runs.
A long generated command or a script handed over as a file defeats
it, even when nothing in it is malicious.

## Author's summary

Subject, one sentence of what changed, pass or fail, and
`git diff --stat`.
The stat is required; scope drift is invisible in prose.

## The ladder

Cheapest first.
Each rung runs only when its failure is possible for this change.
An inapplicable rung is skipped, not performed for form.

- Summary against plan: watch overclaims and scope beyond the plan.
- Scope from the stat: expected files, proportionate size.
  - Stop and flag a disproportionate diff before reading content.
- Signatures by targeted grep: is the substantive change the specified
  one?
- Claims against ground truth, only when the summary makes a
  falsifiable claim.
- Completeness, only when tests discover set members dynamically and a
  missing member would raise no failure.
- Trap reasoning, only when correctness-bearing logic changed:
  - vacuous conditions,
  - boundary inputs,
  - one defect producing many errors,
  - misattributed errors.

Shell adds its own trap class:
a path with a space or glob character, an unquoted expansion, an exit
code swallowed by a pipe, a variable empty rather than unset.
Fixtures have tidy paths and will not surface these.
`shellcheck` catches most, which is why it is part of the floor.

## Changes with no diff

Some changes have no commit and no stat.
Edge rules live in the Bunny interface, not this repository, so a rule
change has no commit, no diff, no test, and no plan entry to grade
against.
Two production failures came from there:
piecemeal rule edits that missed a pattern, and a redirect loop caused
by `%{Path.0-}/` dropping a trailing slash.

For a change of this kind:

- State it in full, as the complete final rule, before applying it.
  - Not as a diff against what is believed to be there.
  - Not in pieces.
- Apply it as one unit.
- Verify it by observed requests, not by reading the rule back.
  - Rule text is a claim; a request is ground truth.
- Record the whole redirect chain, not only the final status.
  - Hop count is what reveals a loop.
  - A looping URL can still end in a plausible code.

Where the repository gains a script for this, the rung becomes running
it.
Until then it is done by hand and stated in the submission.

## Destructive operations

Upload runs in delete mode against live zones, and legacy content has
been deleted outright.
A change that can delete or overwrite live content gets two extra
rungs:

- Pre-flight: state what will be deleted or replaced, enumerated, and
  from which zone, before it runs.
- Approval: the maintainer approves that list explicitly.
  - Approval is for that list, not for the operation in general.

Scope that is cheap to rebuild and scope that is not are different
risk classes.
The site zone regenerates from a build.
The pics zone means re-uploading renditions and originals over a home
link.
A change touching the pics zone is treated as the expensive class
however small it looks.

## Probe kit

Around fifteen lines total, targets derived from the plan.
The plan names the new symbol, the removed token, and the assertions
promised.

- Grep assertions in changed test files, not just test names.
- Grep source for the removed token; empty output is the proof.
- Grep tests for the new function or stage name.
  - Confirms something exercises it, not only defines it.
- Grep assertions for hardcoded literals.
  - Especially paths, zone names, and status codes.
  - A literal the test does not care about is often a missing
    configuration line.

Use `grep -I --include='*.sh' --include='*.bats'`.
Exclude `_build/` and any vendored tree.

These confirm the tests assert the right thing for the cases they
name.
Going past the author's chosen cases needs independent ground truth:
a real zone listing or an observed HTTP response, never a value the
script itself produced.

## Deleting a rung

When a failure mode recurs, push it into a suite assertion so it goes
red on its own instead of costing a review pass.

## Manual acceptance run

The suite proves correctness on generated fixtures, not behavior on
real data or live zones.
State in the submission that the run happened and what was observed.
"Deployed fine" is not an observation; name what was checked.

For changes touching the build path, run the pipeline on a real
collection before final sign-off and check what fixtures cannot:

- no dangling symlinks,
- output validates against the upstream schema,
- files open through the links,
- counts match config.

This has caught producer drift that every fixture test passed.

For changes touching the deploy path, after the deploy runs:

- Each public URL form returns what it should.
  - On both the `gallery/` and `galleries/` prefixes.
- Redirects resolve in the expected number of hops.
- Renditions still serve from the pics zone.
- Nothing was deleted that was not in the approved pre-flight list.

## The reviewer is not exempt

An inferred hazard is a claim, not a finding, until checked against
the code or the contract.
Do not escalate one to the maintainer before reading the source that
would confirm or dismiss it.
If the spec or code answers a question, read it rather than asking.

State a correction once and move on.
Do not restate a corrected position as the original, or re-explain one
fact in varying forms.

## Sign-off

Commits match the plan, scope is contained, claims check out, and the
applicable rungs found nothing.
Open items go back as surgical requests, not a direction to start
over.

A dependency-ordered change is signed off per commit rather than as a
unit: plan, sign off, implement, summarize, sign off, commit, next.
Encode that ordering in its `doc/TODO.md` section with the reason each
step precedes the next.