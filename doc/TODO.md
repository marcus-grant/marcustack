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

### ft/rclone-site-upload

The site zone moves from the curl uploader to rclone,
over Bunny's S3-compatible storage API.
This replaces the planned upload parallelism work, now cancelled:
rclone gives concurrency and hash-based incremental sync directly.

Settled:

- rclone uploads the site zone; the pics zone stays on curl.
  - Two upload mechanisms is the accepted temporary price.
  - Moving pics is low priority and tracked separately.
- The curl site upload stays in the repo, runnable and selectable.
  - It is marked deprecated.
  - It retires when Bunny announces S3 as generally available.
    - A condition, not a date.
- Every sync runs with `--checksum`.
  - Without it, rclone compares size and time, not content hashes.
- Stage start and end lines and the run header stay as they are.

Field-tested on throwaway zones, all since deleted:

- Frankfurt S3 endpoint: `https://de-s3.storage.bunnycdn.com`.
  - Access key ID is the zone name; the secret is the zone password.
  - rclone backend `s3`, provider `Other`, region left blank.
- S3 can only be enabled when a zone is created.
  - Zones cannot be renamed, so the new zone's name is final.
  - S3 zones exist only in Frankfurt, New York and Singapore.
  - Bunny's docs call S3 a closed preview; this account has access.
- Listings carry an MD5 equal to the local file's MD5.
  - That holds for single-request uploads.
  - rclone's multipart cutoff is 200 MiB; gallery files are far below.
- Full site tree, 2598 files, 16 parallel transfers:
  - about 15 seconds, 0 errors, 0 retries, 0 refused requests,
  - so `--tpslimit` is not needed;
  - a rerun on the unchanged tree copied nothing, in under 1 second.
- Repointing an existing pull zone's origin to another storage zone:
  - keeps the hostname, edge rules and settings,
  - took effect in about 20 seconds.
- Trap: never grep a transfer log for bare numeric status codes.
  - Photo file names carry timestamps such as `T185429`.
  - Match status codes in their response context instead.

Decided:

- Credentials: `~/.config/marcustack/gallery/rclone.conf`.
  - Created by the maintainer with `rclone config --config PATH`.
  - marcustack checks it is readable and passes `--config PATH`.
  - marcustack never reads the file.
  - One remote per gallery zone: `site` now, `pics` when pics moves.
  - Zones serving more than the gallery get a separate file.
- The new site zone:
  - Frankfurt primary, S3 enabled, New York replication,
  - on the old site zone's storage tier.
  - Replication regions can be added later but never removed.
  - Its name is chosen by the maintainer and never printed.
  - Visitors reach the pull zone's hostname, which a repoint keeps.
- The transport is chosen by a `[deploy]` config key.
  - `rclone` when the key is absent.
  - curl is deprecated and expected to be removed.
  - It stays only while Bunny's S3 API is a preview and still changing.
  - The key's name is decided against the code.
- One `rclone sync` per directory, four in all:
  - `pics/COLLECTION/preview`,
  - `pics/COLLECTION/thumb`,
  - `gallery/COLLECTION` to `gallery/COLLECTION`,
  - `gallery/COLLECTION` to `galleries/COLLECTION`.
  - An explicit list fails visibly when galleria adds a directory.
    - Exclude filters would publish anything new by default.
  - galleria v0.0.6 writes its stylesheets inside `gallery/COLLECTION/`.
- rclone's timeouts come from config, never hardcoded.
  - Whether they share `stall_seconds` is decided when planned.
  - rclone's retries stay at its defaults.
  - curl's `stall_seconds` behavior for the pics zone does not change.
- The old site zone is kept through migration and acceptance.
  - One read-only curl listing of the new zone decides the fallback.
  - HTTP 200: the curl fallback targets the new zone.
    - The old zone is then deleted after acceptance.
  - Otherwise the old zone stays as the fallback target.

Migration, in order:

- Create the new S3 site zone and the rclone config file.
- Probe the new zone with one read-only curl listing.
- Sync the current build to the new zone.
  - It is galleria v0.0.5 output, identical to what is live.
  - Both zones then hold the same content.
- Repoint the live site pull zone's origin to the new zone.
- Purge the pull zone's cache as insurance.
- Switch the config to the new zone.
- Acceptance:
  - a deploy that syncs to the new zone and copies nothing,
  - public gallery URLs still serving on both prefixes.
- Delete the old site zone, only if the probe returned HTTP 200.
  - A destructive operation under `doc/QA.md`.
  - Its pre-flight list is that one zone.

The closing Doc commit brings `doc/ecosystem.md` current:

- Critical path: the live-gallery gate is discharged.
- Project statuses for galleria and marcustack are stale.
  - galleria v0.0.6 is released; the live gallery runs v0.0.5 output.
- Transport:
  - rclone over FTP stays ruled out,
  - rclone over S3 is adopted for the site zone,
  - curl stays as the deprecated fallback until S3 is GA,
  - with the zone constraints above.
- Add the HTML staleness rule, and whether it is live at the edge.
- Scope of that doc: what each project is, its status,
  - cross-project contracts and boundaries, settled decisions,
  - never another project's internals.
- `doc/CONTRIBUTE.md` tells the rclone story as FTP only.
  - Keep the lesson, and say that S3 is the path that works.

### HTML revalidation rule at the edge

Must be live before the galleria v0.0.6 deploy.
It is an edge rule in Bunny's interface, not a code change.
Its full text is also written into `doc/ecosystem.md`,
so the rule has a diff and a review.

The rule, settled:

- Content-addressed artifacts are immutable.
  - A new build means a new name, so they cache for a long time.
- HTML is the only mutable artifact.
  - Same URL every build.
  - It is also what names the immutable artifacts to fetch.
- So HTML revalidates on every request, and everything else caches long.
  - Revalidation over a fixed short lifetime:
  - an unchanged page costs a returning visitor a 304,
  - and a deploy shows up immediately.

Why it is urgent now:

- galleria v0.0.6 prunes superseded stylesheets.
- The delete-mode sync then removes them from the zone.
- A browser holding a page from before a deploy:
  - fetches a stylesheet that is gone,
  - and renders unstyled until it revalidates.

Steps:

- Observe current caching headers on one page and one asset.
  - `Cache-Control`, `ETag` and `Last-Modified`.
  - Revalidation only works if `ETag` or `Last-Modified` is sent.
- Write the complete rule, and apply it as one unit.
  - See "Changes with no diff" in `doc/QA.md`.
- Verify by real requests:
  - a page comes back marked for revalidation,
  - a repeat request with its validator returns 304,
  - an asset comes back with a long lifetime.
- Cover both prefixes, `gallery/` and `galleries/`.
  - Include trailing-slash URLs, which serve a page without `.html`.

### ft/output-modes

marcustack's output gets two renderers over one event stream.
Lands after `ft/rclone-site-upload`.

- One emit function takes a structured event.
  - Stage, status, and detail.
  - It formats the event for the current mode.
  - Never two sets of print statements.
    - They drift, and the log ends up saying what the terminal did not.
- Mode:
  - from `[ -t 1 ]` on stdout,
  - plain when `NO_COLOR` is set or `--no-color` is passed,
  - since a pipe is not the only reason to go plain.
- Colour through `tput`, never hardcoded escape codes.
  - `TERM=dumb` then degrades on its own.
- Log renderer: timestamps, a stage prefix, one event per line.
  - That is what makes the log greppable.
- Terminal renderer: no timestamps, colour and alignment.
- rclone's output follows the same mode.
  - Terminal: `--progress`.
  - Log: `--stats 10s --stats-one-line`.
  - So the mode must reach the rclone call, not only marcustack's lines.
- Keep the stage start and end lines and the run header.

Acceptance is the galleria v0.0.6 deploy:

- First pin `[galleria] version = "v0.0.6"`
  - in the live config and in `config.example.toml`.
- The HTML revalidation rule must be live first.
- v0.0.6 is the first release that changes rendered output.
  - Rewritten pages and two new content-addressed stylesheets.
- Observe, in both output modes:
  - a first sync that copies the changed pages and the stylesheets,
  - a second sync of the same tree that copies nothing,
  - the `galleries/` mirror matching `gallery/`.
- Then check delete mode, since this deploy supersedes no stylesheet.
  - v0.0.5 output has no stylesheet files, only an inline style block.
  - Copy a live stylesheet within the zone, named like an older build's.
    - A copy keeps live pages styled; a rename would not.
  - Rerun the deploy: the copy is deleted and nothing else changes.
  - A destructive run under `doc/QA.md`.
    - Its pre-flight list is the copy.
  - This checks marcustack's delete-mode sync.
    - galleria's own pruning is galleria's to test.
- Report what was observed, not that it worked.

### Richer CLI output

Deferred. Whatever `ft/output-modes` leaves undone.

- marcustack's own stage-level output, beyond the two renderers.
  - rclone's transfer output is not part of this.
- Possibly more colour and better layout.
- Clean bypasses when stdout is a pipe or a log, not a terminal.
  - This is the awkward part in shell:
    - TTY detection, and stripping colour by hand.
  - It's one input to the open question:
    - whether to port parts of marcustack to Python.
  - It is one input to the open question of porting parts of
    marcustack to Python.
  - When this lands, report to the director for the ecosystem.
    - We need to further the discussion of pro vs con of Python vs shell.
    - The director should provide a block of text for us to save to:
      - ecosystem.md or this TODO doc.

### Deployment status command

Nothing records what is on the CDN; the zone listing is the only truth.
pics is write-once, so mistakes accumulate there permanently.

- A read-only dry run against the zone listings.
  - Reports per directory what a deploy would put, delete, and skip.
  - Transfers nothing.
- It is the enumerated pre-flight list that `doc/QA.md` requires
  - before any deploy that can delete or overwrite live content.
- Built on `rclone sync --dry-run --checksum`.
  - Site zone first, after `ft/rclone-site-upload`.
  - Pics zone when it moves to S3, with the same command.
  - No curl-based version: it would be thrown away at that move.

### Deployment manifest and prune

Superseded content-addressed files accumulate in the site zone.
A deploy uploads new names but nothing tracks when old ones went out.

- A manifest written at deploy time.
  - What is online, and when each artifact was superseded.
  - A zone listing knows what is online; only history knows when.
- A prune job removes superseded artifacts after a retention window.
  - The window must outlive any page a browser may still hold.
  - A tab left open for a day sets the floor.
  - This argues against aggressive cleanup.
- Hard scope: the site zone only, never the pics zone.
  - Re-uploading pics content over a home link is a slow restore.
- Open, to discuss before it is built: Python instead of shell.
  - It needs structured state written at deploy time,
  - compared across history with timestamps and retention arithmetic.
  - That is where shell stops being pleasant.
  - Everything else currently planned stays in shell.

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

### Link verification

An explicit sync list misses any directory galleria adds.
Checking the built links catches that before upload.

- Never by requesting every link from the public site.
- The full link set is checked against files:
  - before deploy, against the local build tree, offline,
  - after deploy, against the zone listings, one per synced directory.
    - Possibly through `rclone check`.
- Links into `original` and `display` reach the pics zone by redirect.
- Edge behavior stays with "Endpoint verification", by a small sample.
  - Only a request can observe an edge rule.
- It complements that entry: the expected set comes from the build.
- Open, decided against the code:
  - the tool, possibly an existing offline link checker,
  - how links into the pics zone are represented,
  - a pipeline stage or a separate `just` recipe.

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

### Move the pics zone to S3

Low priority, but it will happen.
The pics zone holds originals and display copies.

- Same path as the site zone in `ft/rclone-site-upload`:
  - a new S3 zone, a full sync, a pull zone repoint, a purge.
- It is the slow case for curl.
  - A new collection uploads hundreds of large files sequentially.
- Once done, the curl uploader has no remaining user.
  - Unless the S3 fallback is still needed, it can then be removed.

## Project housekeeping

- Restructure `doc/` into topic subdirectories
  when the flat shape stops scaling.
  Trigger: more than ~5 files, or two clearly distinct topic clusters emerge.
