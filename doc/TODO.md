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

### ft/cdn-deploy

Goal: put galleria's gallery online.
Run `galleria build` against `_build` and upload the result to the
CDN.
No deprecation banner.
The branch name is proposed, not settled.

The `_build` layout is reworked first; the upload depends on it.

- Today normpic writes `_build/manifests/full` and
  `_build/manifests/web`, each a manifest plus a symlink tree.
  Galleria's per-photo pages reach those trees only through two
  hand-made links, `_build/pics/COLLECTION/original` and `display`.
- Rework: normpic invocations land the symlink trees directly at
  `pics/COLLECTION/original/` and `pics/COLLECTION/display/`, beside
  galleria's `preview/` and `thumb/`, so the served tree is complete
  without hand-made links.
- Both `original/` and `display/` must be present in the served tree.
  Every per-photo page shows `display/` and links `original/` twice,
  so a missing rendition dir 404s every per-photo page.
- Remaining details are decided against the code during this slice:
  where the manifest file sits relative to the served tree, and what
  the upload does with symlinks.

marcustack depends on galleria's output layout.
The verify stage asserts it, so an upstream change fails loudly:

- Site root is galleria's `--output-dir`.
- Pages at `gallery/COLLECTION/pageN.html`, `index.html` a copy of
  `page1.html`, per-photo pages at `gallery/COLLECTION/pic/STEM.html`.
- Renditions at `pics/COLLECTION/KIND/`, kinds `original`, `display`,
  `preview`, `thumb`.
- All links relative; galleria knows nothing of buckets or hostnames.

Open, decided against the code and brought to the maintainer:

- Whether upload is idempotent, and what "already uploaded" means.
- Whether a record of what is on the CDN belongs here or next.

## Project housekeeping

- Restructure `doc/` into topic subdirectories
  when the flat shape stops scaling.
  Trigger: more than ~5 files, or two clearly distinct topic clusters emerge.
