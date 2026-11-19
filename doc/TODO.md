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

### Upload parallelism

Upload is sequential, one curl per file, and slow.

- Per-request latency dominates, about 3 seconds per file.
  - File size barely matters.
  - A 200 Mbit link runs at a quarter utilization.
- Parallel PUTs with a bounded worker count are the known fix.
  - The worker count is a config tunable with a program default.
- Per-transfer `i/T` progress lines must stay readable in parallel.
- Acceptance needs a deploy with real transfers, not an all-skip one.
  - The first galleria release that changes rendered output supplies it.
  - It also exercises per-transfer progress lines on real data.

### Deployment status command

Nothing records what is on the CDN; the zone listing is the only truth.
pics is write-once, so mistakes accumulate there permanently.

- A read-only dry run against the zone listings.
  - Reports what a deploy would put, delete, and skip.
  - Transfers nothing.

### Endpoint verification

Edge rules live in the Bunny interface, not this repository.
A rule change therefore has no commit, no diff, and no test.
Two failures came from there:
a pattern missed by piecemeal rule edits,
and a redirect loop from `%{Path.0-}/` dropping a trailing slash.
Rule text is a claim; an observed request is ground truth.
Reading rules back through Bunny's API, if it offers that,
would have caught the first failure and not the second.

- A script in this repository, run as a stage.
  - Requests each public URL form and asserts the result.
  - Read-only and needs no credentials.
    - Anyone can run it at any time.
- Config carries a named list of entries.
  - Each entry has a path and an expected status.
  - The script loops the list and reports each entry.
  - The exact shape is open; decide against the code when built.
- Redirect depth is capped, and exceeding the cap is a failure.
  - No per-entry setting; a redirect loop is always wrong.
- Coverage:
  - both the `gallery/` and `galleries/` prefixes,
  - the bare and trailing-slash forms,
  - pages and a per-photo page,
  - one URL under each rendition kind.
- Once it exists, it replaces the by-hand rung in `doc/QA.md`.
  - That rung is "Changes with no diff".

### Pin normpic through uv tool run

normpic runs from a separately installed tool,
while galleria runs at its configured tag through `uv tool run`.
The installed normpic can drift from the `[normpic]` pin in config.

- Run normpic through `uv tool run` at the configured tag.
  - The run header then reports the pin, as it does for galleria.
- Rework `normpic_schema_path` in `scripts/lib/verify.sh`.
  - It searches the installed tool's directory for the schema.
  - `uv tool run` does not populate that directory.
- Remove the test suite's dependency on an installed normpic.
  - The pipeline calls `normpic_schema_path` before any stage.
  - Without normpic installed, the script exits there.
  - The stubs never run, so a pipeline test fails.
    - "pipeline invokes normpic with per-kind dest dirs".
- Retire the `just install-normpic` recipe.

## Project housekeeping

- Restructure `doc/` into topic subdirectories
  when the flat shape stops scaling.
  Trigger: more than ~5 files, or two clearly distinct topic clusters emerge.
