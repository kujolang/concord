# Changelog

All notable changes to Concord are documented here.

## [Unreleased]

- Recognize Node, npm, npx, and Tribunal README command examples.
- Parse `package.json` name and version values without retaining JSON field syntax, preventing false manifest and version drift.
- Detect current Kujo Eval suites that use top-level `tests` and per-test `check` fields.

## [1.0.0] - 2026-06-27

- Prepared Concord for public release with artifact drift scans, category checks, JSON/Markdown reports, task export output, and self-dogfood test coverage.
