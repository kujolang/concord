# Concord

[![Version](https://img.shields.io/badge/version-1.0.0-black)](https://github.com/kujolang/concord)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)
[![built with Kujo](https://img.shields.io/badge/built%20with-Kujo-white.svg)](https://github.com/kujolang/kujo)

A local drift-checking tool that compares the important artifacts in a repo and surfaces mismatches. Built in [Kujo](https://github.com/kujolang/kujo) as an ecosystem dogfood showcase.

Concord surfaces drift and follow-up work; it does not prove correctness or replace review.

Concord helps answer:

> Do the code, CLI, docs, examples, Spec files, Eval checks, schemas, package metadata, and release artifacts still describe the same product?

## Quick Start

From this repo:

```bash
kujo run concord.kujo -- scan
```

Expected report shape:

```text
# Concord Drift Report
...
## Summary
...
```

Useful follow-ups:

```bash
kujo run concord.kujo -- scan --format json
kujo run concord.kujo -- scan --output /path/to/report.md
kujo run concord.kujo -- check cli-docs
kujo run concord.kujo -- check --format json cli-docs
kujo run concord.kujo -- tasks
kujo run concord.kujo -- scan --dir /path/to/other-project
```

Concord recognizes copyable Kujo, Cargo, Git, shell, Node, npm, npx, and standalone Tribunal command examples in fenced README and recursively discovered docs blocks. It compares documented Kujo subcommands with explicit subcommand dispatch in the configured CLI entry source without executing repository code. JavaScript package metadata uses structured JSON parsing; supported YAML/TOML metadata uses exact-key, line-aware scalar extraction.

Recursive docs, Eval, and example discovery is deterministic and bounded to depth 4, 256 matching files, and 2,048 visited directory entries per discovery root. Canonical path checks prevent traversal through symlinks outside that root. Text artifacts larger than 1 MiB are reported as high-severity incomplete-scan findings instead of being read or silently truncated.

## Commands

| Command | Description |
|---------|-------------|
| `scan` | Run all drift checks and produce a full report |
| `check <category>` | Run a specific check category and exit `3` when findings are present |
| `report` | Run all checks and generate an artifact report |
| `tasks` | Generate follow-up fix task cards from scan findings |
| `version` | Print version information |
| `help` | Print usage information |
| `--help` | Print usage information |
| `--version` | Print version information |

Use `scan`/`check` to find drift; use `report`/`tasks` to export findings and follow-up work.

## Check Categories

| Category | Description |
|----------|-------------|
| `cli-docs` | CLI ↔ Docs alignment — are documented commands real? |
| `spec-eval` | Spec ↔ Eval alignment — do specs have matching eval checks? |
| `manifest` | Manifest ↔ Docs alignment — does package metadata match docs? |
| `versions` | Version consistency — is the version the same everywhere? |
| `examples` | Example validity — do example commands reference real files? |
| `source-of-truth` | Source-of-truth mapping — which artifact is authoritative? |
| `all` | All checks (same as `scan`) |

## Options

| Option | Description |
|--------|-------------|
| `--dir <path>` | Target directory (default: current directory) |
| `--format markdown\|json` | Output format (default: markdown) |
| `--output <path>` | Write report to file instead of stdout |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | No drift or only low-severity findings |
| 1 | High-severity or critical drift found |
| 2 | Error (invalid arguments, etc.) |
| 3 | `check` found findings and returned a verification failure |

## Requirements

- Kujo runtime available as `kujo` on `PATH`
- Run inside a project directory (git repo recommended)
- `jq` for the optional continuous-loop workflow

## Readiness Posture

Concord is useful as a local drift review tool and Kujo dogfood showcase, but it should not be described as enterprise-ready yet. The package manifest currently marks it as `experimental` and `early`; that is intentional until the scanner has broader fixture coverage, documented false-positive expectations, and hardened output/path handling.

Current strengths:

- Rule-based checks with stable Markdown and JSON report shapes
- Explicit exit codes for CI-style use
- Self-dogfood coverage through this repo's Spec, tests, eval metadata, examples, and manifests
- No network services or AI dependencies

Known maturity boundaries:

- YAML/TOML support intentionally covers exact-key scalar metadata rather than the full languages
- Markdown command extraction is fenced-block and convention based
- Findings are drift leads for review, not proof of correctness
- The default scan is single-repo and convention-oriented
- Enterprise rollout should add policy configuration, larger fixture suites, and clearer output safety rules

## Running Tests

```bash
kujo test
bash tests/continuous_loop_tests.sh
```

## Contributor and Agent Notes

Prioritize copyable examples over tests: examples should model the most token-efficient idioms we want agents to imitate.

Canonical surfaces:

- `README.md` Quick Start and command tables are the copyable user-facing examples.
- `concord.kujo` help text is the CLI contract surface.
- `tests/concord_tests.kujo` is the active behavior test suite.

Search hygiene:

- Start with `README.md`, `concord.kujo`, `src/**/*.kujo`, and `tests/concord_tests.kujo`.
- Exclude generated/bulk paths from the main sweep unless the task explicitly targets them; this repo's generated output is expected under `.dogfood/concord/loop/`.
- Treat `tests/concord_tests.out` as expected-output data, not an example to shorten.
- `examples/README.md` contains copyable usage examples for humans and scan fixtures for Concord.
- `tests/concord_eval.json` is lightweight eval metadata used to keep the Spec/Eval alignment surface present in this repo.

## Continuous Loop (All Four Tracks)

Use the loop runner to execute the full continuous workflow repeatedly:

1. Repository matrix scans with JSON/Markdown outputs
2. Trend artifact updates
3. Category regression snapshots and gate summary generation
4. Upstream issue draft refresh linked to dogfood findings

```bash
# Single cycle
scripts/concord_continuous_loop.sh --iterations 1

# Continuous loop every 10 minutes
scripts/concord_continuous_loop.sh --iterations 0 --sleep-seconds 600

# Strict mode for CI-style gating
scripts/concord_continuous_loop.sh --iterations 1 --strict-gate

# Bound retained trend history (default: 10,000 rows; 0 keeps all rows)
scripts/concord_continuous_loop.sh --iterations 1 --trend-max-records 5000
```

Artifacts are written under `.dogfood/concord/loop/`:

- `.dogfood/concord/loop/runs/<timestamp>/`
- `.dogfood/concord/loop/trend/scan-trend.jsonl`
- `.dogfood/concord/loop/trend/latest-summary.md`
- `.dogfood/concord/loop/upstream-issue-drafts.md`

Each cycle uses a unique run directory, artifact names are collision-safe within a repository matrix, and high-severity findings remain normal scan results rather than being mislabeled as scan failures. The trend JSONL is bounded to 10,000 rows by default; use `--trend-max-records 0` only when unbounded retention is intentional.

## Project Structure

```
concord.kujo              # Main entrypoint
README.md                 # User-facing documentation and copyable commands
concord.spec.yml          # Spec file (task definition)
kujo.toml                 # Kujo project config
kennel.toml               # Kennel package manifest
LICENSE                   # MIT license
kujo                      # Repo-local wrapper; requires KUJO_RUNTIME_BIN
src/
  common.kujo             # Shared utilities (arg parsing, string helpers)
  scanner.kujo            # Artifact discovery and file detection
  checks/
    shared.kujo           # Shared bounded-artifact findings
    cli_docs.kujo         # CLI ↔ Docs alignment checks
    spec_eval.kujo        # Spec ↔ Eval alignment checks
    manifest_docs.kujo    # Manifest ↔ Docs alignment checks
    version_consistency.kujo # Version consistency checks
    example_validity.kujo # Example validity checks
    source_of_truth.kujo  # Source-of-truth mapping
  reporter.kujo           # Markdown and JSON report generation
  fix_tasks.kujo          # Fix task card generation
examples/
  README.md               # Copyable example commands
tests/
  concord_tests.kujo      # Test suite
  concord_eval.json       # Eval metadata for Spec/Eval alignment checks
docs/
  NEXT_REVIEW_2026-06-19.md # Follow-up readiness review checklist
.dogfood/concord/         # Ecosystem dogfood reports
```

The root files above are intentional contract files rather than leftovers from the pre-`src/` layout. Implementation modules live under `src/`; the root remains the place for the executable entrypoint, project/spec manifests, license, wrapper, and README.

## How Concord Differs from Other Dogfood Tools

| Tool | Scope | Concord's Relationship |
|------|-------|----------------------|
| **PatchBrief** | Git diff → implementation briefs | PatchBrief explains changes; Concord checks whether patch-facing docs and commands stay aligned |
| **ShipCheck** | Release-readiness scanner | ShipCheck tracks release gates; Concord tracks drift between artifact sources of truth |
| **Trail** | Onboarding/HOWTO verification | Trail verifies onboarding docs; Concord checks whether examples and docs still agree |
| **Scout** | Codebase intelligence | Scout maps repositories; Concord focuses on cross-artifact alignment, not code analysis |

## Status

Early dogfood build. Concord is already useful for local artifact-drift review, and the next milestone is broader fixture-backed hardening toward production-grade adoption.

## License

MIT
