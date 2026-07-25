# Concord Next Review Checklist - 2026-06-19

This checklist captures the next set of improvements to move Concord from a useful early dogfood tool toward a production-grade, broadly useful artifact-drift checker.

## Current Session Baseline

- Tests pass with `KUJO_RUNTIME_BIN=kujo ./kujo test`.
- Concord self-scan returns zero findings after adding repo-local eval metadata and examples.
- CLI argument handling now rejects missing option values and unsupported `--format` values with exit code `2`.
- `check` can now find its category when flags appear before the category, such as `check --format json cli-docs`.
- CLI entry discovery now reads `entry` from both `kennel.toml` and `kujo.toml`.

## Performance Enhancements

- Add a shared artifact inventory so checks do not re-read README, manifests, Spec files, examples, and eval files independently.
- Add bounded recursive discovery for docs, examples, and eval files with explicit excludes for `.git`, `.dogfood`, build outputs, package caches, and dependency directories.
- Add large-file caps and binary-file detection before reading arbitrary project files.
- Add optional timing metadata to JSON reports so slow checks can be identified without profiling manually.
- Consider stable sort ordering for findings and category keys to make reports easier to diff in CI.

## Security Enhancements

- Normalize and validate `--output` paths before writing; reject directories and optionally require parent directories to exist.
- Document overwrite behavior for `--output` and consider a `--force` or `--no-overwrite` policy before broader adoption.
- Treat scanned repositories as untrusted input: avoid executing project commands by default, and keep current source-parsing behavior unless an explicit opt-in execution mode is added.
- Add path traversal fixtures for documented paths, output paths, and manifest-declared entrypoints.
- Add malformed JSON/YAML/TOML/Markdown fixtures to confirm Concord reports drift safely instead of crashing.

## Functionality Increases

- Add a `.concord.toml` or manifest-driven configuration file for ignores, expected missing artifacts, severity overrides, and project conventions.
- Add SARIF output for code scanning integrations.
- Add JSON schema documentation for report output and findings.
- Expand checks to include docs outside `README.md`, including nested `docs/**/*.md`.
- Add artifact-path validation beyond command flags so docs that mention important files can be checked even outside command examples.
- Add fixtures for non-Kujo projects so Concord becomes useful outside the Kujo ecosystem while still showcasing Kujo.
- Add release-note and changelog alignment checks once the ecosystem has consistent conventions.
- Add a fixture corpus with expected reports for clean, low-drift, high-drift, malformed, and intentionally unconventional repos.

## Presentation And Packaging

- Keep the README honest: useful early dogfood tool, not enterprise-ready yet.
- Add screenshots or short report excerpts only after the report format stabilizes.
- Keep root contract files in place: `concord.kujo`, manifests, spec, wrapper, license, and README belong at repo root.
- Keep implementation code in `src/` and tests/fixtures in `tests/`, `examples/`, and future `fixtures/`.
- Before claiming production readiness, update `kennel.toml` status from `experimental`/`early` only after fixture coverage and output/path safety are stronger.

## Suggested Next Session Order

1. Build fixture repos under `tests/fixtures/` and add expected report assertions.
2. Add output-path validation and tests.
3. Introduce shared artifact inventory caching.
4. Add configurable ignores/severity overrides.
5. Re-run `./kujo test`, `concord scan`, `concord scan --format json`, and focused category checks.
