# TODO

marcustack is the orchestration layer for the personal-site stack.
See `v01.md` for the MVP plan and the longer-form context.

## Conventions

- Markdown line width under 80 characters.
- No em dashes anywhere; use a period and a new sentence instead.
- ASCII only; no Unicode.
- Sentence-ending punctuation (`.`, `!`, `?`) always ends a line.
- TDD wherever behavior is deterministic.
- Tests run via `just test` (bats-core).
- Lint via `just lint` (shellcheck).
- All tasks invoked through `just`.
- License: GPL-3.0.
- Versioning: semver.

## Planned PRs

PRs land in order unless explicitly noted.
Each PR is small enough to read in one sitting and ships one cohesive
chunk of behavior.

### PR-001: Complete the stage outcome contract

Goal: finish the outcome-capture half of the stage contract.
Picks up where the bootstrap commit left off (which implements
spec 1 from `v01.md` Stage contract).

In scope:

- Spec 2: `run_stage` writes `failure` when the command exits nonzero.
- Spec 3: `run_stage` does not abort the spine on stage failure.

Out of scope:

- Output atomicity (deferred to a later PR).
- Stage sequencing across multiple stages (deferred to a later PR).

Acceptance: `tests/stage.bats` passes specs 1 through 3.

## Project housekeeping

- Restructure `doc/` into topic subdirectories
  when the flat shape stops scaling.
  Trigger: more than ~5 files, or two clearly distinct topic clusters emerge.