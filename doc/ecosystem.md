# Ecosystem

MarcusTack is a set of small projects that together publish a personal
site and photo galleries.
This document is the current state, the order work happens in, and the
decisions that are settled.

## Critical path

Normpic `v0.1.1` -> galleria -> marcustack deploy.
Gated, not parallel.
Everything else waits for a live gallery.

## Projects

- **normpic** (Python): produces photo copy manifests and symlink
  trees.
  `v0.1.1` published, contract frozen.
  Parked.
- **galleria** (Python): static gallery generator, consumes normpic
  manifests.
  Next up.
  Stops at local output.
- **marcustack** (shell + just): pipeline orchestrator.
  Owns deploy, CDN, and `CONTENT_PATH` staging.
  Running a bounded slice that invokes normpic on a local collection.
- **personal-site** / **personal-site-content** (11ty): renderer and
  content, `marcusgrant.se`.
  Bootstrapped, parked.
- **retro-theme** (CSS): shared design system, PicoCSS base.
  Documentation only.
  Resumes when a second consumer exists.
- **non-committal** (Rust): git-management daemon for content repos.
  Bootstrapped, parked.
- **zk-notes**: wiki content repo.
  Rendering and search deferred.
- **depo**: `depo://` URI scheme for rich content references.
  Independent and active.

## Settled decisions

### Content addressing

Prefix is `b3c32:`, naming the shared b3c32 library.
Unkeyed BLAKE3-120, Crockford Base32, XOF grow-only so shorter digests
are byte-prefixes of longer ones.
The library owns the vectors and conformance tests.
Consumers pin it and run a drift tripwire; they do not build vectors.
depo binds the canonical form as its durable key.

### NormPic contract

Frozen at `v0.1.1`.
The consumer surface is `doc/architecture/manifest-contract.md`,
`schema/v0.1.1.json`, and `doc/guides/manifest-integration.md`.
Variant collections are deferred in `v0.1.1`,
so one manifest describes one collection root.
Pairing happens across two manifests from two runs, matching on
`relative_path`.
`original_filename` is unpopulated by current producer paths.
Consumers must not depend on its absence.

### Stage contract

marcustack runs stages as `run_stage NAME -- CMD`.
It calls other projects through their CLI, never their task runner
recipes, so recipe renames cannot break the pipeline.
Operation parameters live in marcustack, not in the tools it calls.

### Single source of truth

Where a contract exists as both a canonical artifact and a code
definition, they drift.
The artifact is the source; the code copy is deleted or derived, and a
conformance test guards it.

### Storage split

Storage splits by asset lifecycle.
normpic-manifested originals live in a pics bucket: write-once, large,
rarely fetched.
Site output, including galleria's derived renditions, lives in a site
bucket: regenerated on build, small, frequently fetched.
The edge routes the rendition prefixes to the pics bucket.
Bucket configuration and edge routing belong to marcustack.
Galleria emits relative paths and knows nothing of buckets or
hostnames.

## Deployment

marcustack owns the path from galleria's output to the CDN.
The wedding gallery is live through it.

Settled:

- The storage split above.
- Variant names in config and edge routing are `original` and
  `display`, matching galleria's rendition kinds.
- Transport is Bunny's HTTP storage API via curl.
  rclone over FTP is ruled out: its FTP client desyncs against
  Bunny's daemon and every transfer errors after the 226 reply.
  Zone listings return per-file SHA256, so idempotence is
  content-true without a local record.
- Two zones total, shared by every gallery collection; each
  collection is a subtree keyed by collection name.
  Zone-per-gallery is rejected as needless.
- Edge rules on the site pull zone, both collection-generic:
  - 302 `*/pics/*/original/*` and `*/pics/*/display/*` to the pics
    pull zone, full path preserved.
  - 301 `*/gallery/*` without an extension to its trailing-slash
    form, because the storage origin serves directory indexes
    without redirecting and relative links then resolve one level
    shallow.
  - Trap, learned live: rule conditions match the full URL
    including hostname, so a bare `*.*` negation matches every
    request via the hostname's dots.
    Anchor negative patterns past the host: `*/gallery/*.*`.

Target architecture, recorded, ordering open:

- Each galleria collection builds into its own tree and deploys as
  a subtree of the same two zones.
- personal-site (11ty) deploys to its own third zone when it
  resumes; temporary by design.
- Possible end state: all of marcusgrant.se on exactly two zones,
  one priced for heavy write-rarely assets, one fast for HTML, JS,
  CSS, JSON, and light renditions.
  Documented as a possibility, not scheduled.
- `marcusgrant.se` becomes the base URL for everything; the
  gallery appends `gallery/`.

Post-MVP, dual-deploy migration:

- The legacy `galleries/` path has live spontaneous traffic from
  expected regions, which is the argument for a deprecation year
  rather than a fast cut.
- Galleria emits one build and stays ignorant of the migration.
- marcustack copies that output to two destinations.
- Permanent home: `marcusgrant.se`, plain output, no banner.
- Legacy endpoint: the same output with a deprecation banner
  injected by a script that adds a fixed HTML snippet to the
  relevant HTML files.
  Default assumption is every grid pagination page, or simply
  every HTML file in the legacy copy.
  The exact target set is decided against the code when the item
  is live.
- The banner announces the scheduled deprecation, links to the
  permanent home, and tells visitors to bookmark or write down the
  new address.
- The legacy endpoint and its bucket stay live roughly one year,
  then both are deleted.
- Migration ordering is the open decision; nothing here is
  sequenced yet.

Open, cross-project: the site navbar.

- Galleria's pages sit at two depths, `gallery/COLLECTION/` and
  `gallery/COLLECTION/pic/`, and all links are relative.
- A verbatim fragment cannot carry links that resolve at both
  depths.
  A template override puts two projects in authority over one
  template set.
- Post-processing is the only mechanism that can emit
  depth-correct links per file, and it reuses the banner injection
  mechanism.
- Open: whether one injector handles navbar and banner or two, and
  whether retro-theme or personal-site owns the navbar markup.

## Known gaps

Generated names are deterministic only where EXIF timestamps exist.
Without them, names carry run wall-clock time.
Recorded on normpic's TODO; normpic stays parked.

normpic's copy manifest write is not atomic.
A torn write fails schema validation, so it surfaces as a failed stage
and the operator reruns.
The cost is a wasted run, not corrupt data.

## Conventions

Each repo's ways of working live in its own `doc/CONTRIBUTE.md`.
Read it before working that repo.
TDD is the default everywhere.
