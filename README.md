# Concord

A local drift-checking tool that compares the important artifacts in a repo and surfaces mismatches. Built in [Kujo](https://github.com/kujolang/kujo) as an ecosystem dogfood showcase.

Concord surfaces drift and follow-up work; it does not prove correctness or replace review.

Concord helps answer:

> Do the code, CLI, docs, examples, Spec files, Eval checks, schemas, package metadata, and release artifacts still describe the same product?

## Quick Start

```bash
# Scan the current directory for drift
./kujo run concord.kujo -- scan

# JSON output for programmatic consumption
./kujo run concord.kujo -- scan --format json

# Run a specific check category
./kujo run concord.kujo -- check cli-docs

# Generate fix task cards
./kujo run concord.kujo -- tasks

# Scan another project
./kujo run concord.kujo -- scan --dir ../patchbrief
```

## Commands

| Command | Description |
|---------|-------------|
| `scan` | Run all drift checks and produce a full report |
| `check <category>` | Run a specific check category and exit `3` when findings are present |
| `report` | Generate an artifact report from the last scan |
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

- Kujo runtime (repo-local `./kujo` wrapper; set `KUJO_RUNTIME_BIN` to the actual runtime binary)
- Run inside a project directory (git repo recommended)

## Running Tests

```bash
./kujo test
```

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
```

Artifacts are written under `.dogfood/concord/loop/`:

- `.dogfood/concord/loop/runs/<timestamp>/`
- `.dogfood/concord/loop/trend/scan-trend.jsonl`
- `.dogfood/concord/loop/trend/latest-summary.md`
- `.dogfood/concord/loop/upstream-issue-drafts.md`

## Project Structure

```
concord.kujo              # Main entrypoint
src/
  common.kujo             # Shared utilities (arg parsing, string helpers)
  scanner.kujo            # Artifact discovery and file detection
  checks/
    cli_docs.kujo         # CLI ↔ Docs alignment checks
    spec_eval.kujo        # Spec ↔ Eval alignment checks
    manifest_docs.kujo    # Manifest ↔ Docs alignment checks
    version_consistency.kujo # Version consistency checks
    example_validity.kujo # Example validity checks
    source_of_truth.kujo  # Source-of-truth mapping
  reporter.kujo           # Markdown and JSON report generation
  fix_tasks.kujo          # Fix task card generation
tests/
  concord_tests.kujo      # Test suite
concord.spec.yml          # Spec file (task definition)
kujo.toml                 # Kujo project config
kennel.toml               # Kennel package manifest
.dogfood/concord/         # Ecosystem dogfood reports
```

## How Concord Differs from Other Dogfood Tools

| Tool | Scope | Concord's Relationship |
|------|-------|----------------------|
| **PatchBrief** | Git diff → implementation briefs | PatchBrief explains changes; Concord checks whether patch-facing docs and commands stay aligned |
| **ShipCheck** | Release-readiness scanner | ShipCheck tracks release gates; Concord tracks drift between artifact sources of truth |
| **Trail** | Onboarding/HOWTO verification | Trail verifies onboarding docs; Concord checks whether examples and docs still agree |
| **Scout** | Codebase intelligence | Scout maps repositories; Concord focuses on cross-artifact alignment, not code analysis |

## Status

MVP — dogfood build. Testing the Kujo ecosystem while building a useful drift checker.

## License

MIT
