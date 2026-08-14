# Ecosystem

MarcusTack is a set of small projects that together publish a personal
site and photo galleries.
This document is the current state, the order work happens in, and the
decisions that are settled.

## Critical path

Normpic `v0.1.0` -> galleria -> marcustack deploy.
Gated, not parallel.
Everything else waits for a live gallery.

## Projects

- **normpic** (Python): produces photo copy manifests and symlink
  trees.
  `v0.1.0` published, contract frozen.
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

**Content addressing.**
Prefix is `b3c32:`, naming the shared b3c32 library.
Unkeyed BLAKE3-120, Crockford Base32, XOF grow-only so shorter digests
are byte-prefixes of longer ones.
The library owns the vectors and conformance tests.
Consumers pin it and run a drift tripwire; they do not build vectors.
depo binds the canonical form as its durable key.

**normpic contract.**
Frozen at `v0.1.0`.
The consumer surface is `doc/architecture/manifest-contract.md`,
`schema/v0.1.0.json`, and `doc/guides/manifest-integration.md`.
Variant collections are deferred in `v0.1.0`,
so one manifest describes one collection root.
Pairing happens across two manifests from two runs, matching on
`relative_path`.
`original_filename` is unpopulated by current producer paths.
Consumers must not depend on its absence.

**Stage contract.**
marcustack runs stages as `run_stage NAME -- CMD`.
It calls other projects through their CLI, never their task runner
recipes, so recipe renames cannot break the pipeline.
Operation parameters live in marcustack, not in the tools it calls.

**Single source of truth.**
Where a contract exists as both a canonical artifact and a code
definition, they drift.
The artifact is the source; the code copy is deleted or derived, and a
conformance test guards it.

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
