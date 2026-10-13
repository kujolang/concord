# Changelog

All notable changes to Concord are documented here.

## [Unreleased]

- Add a canonical reference preflight for host-owned private snapshots; reject escaping entry/name fallbacks and example inputs before native checks.
- Normalize Windows separators when checking recursive discovery boundaries.
- Execute the native assertion suite through a fresh-copy VM/interpreter gate, with negative controls and real CLI checks on released Kujo 1.8.1. Wire the wrapper and continuous loop to this gate and add cross-platform CI.
- Correct boolean/integer mismatches in artifact size admission, manifest names, Spec/Eval checks and example output-path handling.
- Read project release versions from changelog headings rather than incidental dependency mentions.
- Parse manifest entrypoints as exact scalar fields and extract command names from full regex matches.
- Keep high-severity `scan --format json` output valid JSON while preserving its nonzero exit status.
- Correct test-only native boolean and nested-index assumptions; clean wrapper temporary storage after execution.

- Added launch-readiness Spec/Eval updates for the Kujo prelaunch review.
- Recognize Node, npm, npx, and Tribunal README command examples.
- Parse `package.json` name and version values without retaining JSON field syntax, preventing false manifest and version drift.
- Detect current Kujo Eval suites that use top-level `tests` and per-test `check` fields.

## [1.0.0] - 2026-06-27

- Prepared Concord for public release with artifact drift scans, category checks, JSON/Markdown reports, task export output, and self-dogfood test coverage.
