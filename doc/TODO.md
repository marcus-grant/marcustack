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

### Unplanned, Needs Home PR

- Ecosystem tool version reporting.
  - A lot of these projects are in early active development.
  - Really need to know what version is acting on the pipeline.

### Upload progress and parallelism

The upload stage is slow and silent.

- Upload is sequential, one curl per file.
  - Per-request latency dominates, about 3 seconds per file.
    - File size barely matters.
  - A 200 Mbit link runs at a quarter utilization.
  - Parallel PUTs with a bounded worker count are the known fix.
- No progress output during verification or upload.
  - The last line on screen stays galleria's "generating static site",
    - while marcustack stages run silently, which misreports the stage.
  - Every stage prints a line when it starts.
  - Upload prints each directory's:
    - planned put, delete, and skip counts...
    - before transferring, then done against planned as it goes.
  - The run header names each tool's resolved version:
    - the galleria tag and the normpic version.

### Deployment status command

Nothing records what is on the CDN; the zone listing is the only truth.
pics is write-once, so mistakes accumulate there permanently.

- A read-only dry run against the zone listings.
  - Reports what a deploy would put, delete, and skip.
  - Transfers nothing.

### Upstream reports

- normpic fails with "File exists" when the source collection moves.
  - Stale links in `pics/COLLECTION/original` and `display`:
    - point at the old path and are not replaced.
  - Workaround: remove those two trees, then rerun.
    - They hold only normpic links and manifests.
  - File upstream in normpic.
- galleria v0.0.4 provides no `galleria` executable; v0.0.3 did.
  - marcustack is unaffected; it runs `python -m galleria`.
  - File upstream in galleria.

## Project housekeeping

- Restructure `doc/` into topic subdirectories
  when the flat shape stops scaling.
  Trigger: more than ~5 files, or two clearly distinct topic clusters emerge.
