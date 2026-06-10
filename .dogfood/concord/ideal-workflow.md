# Concord Ideal Workflow — How It Should Be Built with the Ecosystem

**Date:** 2026-05-28
**Purpose:** Define how Concord should ideally be built using the Kujo ecosystem, not bypassing it.

---

## 1. What Spec Should Provide

Spec should define the Concord task with:

- **name:** `concord`
- **goal:** Build a local developer tool that detects artifact drift and alignment issues in Kujo ecosystem repos
- **background:** Explains why Concord fills the gap between PatchBrief, ShipCheck, and Trail
- **scope:** MVP checks for CLI/docs, spec/eval, manifest/docs, version, and example alignment
- **non_goals:** No network services, no AI/LLM usage, no static analysis engine, no release checker
- **acceptance_criteria:** Specific verifiable conditions for each Concord subcommand
- **eval_requirements:** What Eval checks should validate about Concord's behavior
- **human_approval_points:** Where human review is needed (severity thresholds, source-of-truth declarations)

### Spec file location:
`concord.spec.yml` at the repo root, following the same convention as PatchBrief and ShipCheck.

### Spec validation:
```bash
spec validate concord.spec.yml
```

---

## 2. What Eval Should Verify

Eval should provide deterministic checks that Concord itself works correctly:

### Concord Self-Checks (Eval suite)
```json
{
  "name": "Concord Self-Validation",
  "checks": [
    {
      "name": "concord_scan_succeeds",
      "type": "command_succeeds",
      "command": "kujo run concord.kujo scan --dir ../patchbrief --format markdown"
    },
    {
      "name": "concord_scan_json_valid",
      "type": "command_succeeds",
      "command": "kujo run concord.kujo scan --dir ../patchbrief --format json"
    },
    {
      "name": "concord_report_markdown_has_expected_sections",
      "type": "output_contains",
      "command": "kujo run concord.kujo scan --dir ../patchbrief --format markdown",
      "expected": ["# Concord Drift Report", "## Summary", "## Findings"]
    },
    {
      "name": "concord_report_json_has_expected_keys",
      "type": "json_path_value",
      "command": "kujo run concord.kujo scan --dir ../patchbrief --format json",
      "path": "$.findings",
      "expected_type": "array"
    },
    {
      "name": "concord_exits_nonzero_on_high_severity",
      "type": "exit_code",
      "command": "kujo run concord.kujo scan --dir <fixture_with_known_drift>",
      "expected": 1
    },
    {
      "name": "concord_exits_zero_when_clean",
      "type": "exit_code",
      "command": "kujo run concord.kujo scan --dir <fixture_with_no_drift>",
      "expected": 0
    }
  ]
}
```

### Eval suite location:
`tests/concord_self_eval.json` or defined inline in the spec's `eval_requirements`.

---

## 3. What Dispatch Should Orchestrate

Dispatch could orchestrate Concord as part of a larger workflow:

### Workflow: "Drift Detection and Remediation"
1. **Step: scout-scan** — Run Scout to discover project artifacts
2. **Step: concord-scan** — Run Concord to detect drift (depends on scout-scan)
3. **Step: concord-report** — Generate drift report (depends on concord-scan)
4. **Step: concord-fix-tasks** — Generate fix task cards (depends on concord-report)
5. **Step: human-approval** — Wait for human to approve/reject fix tasks (approval gate)
6. **Step: apply-fixes** — Apply approved fixes (depends on human-approval)
7. **Step: concord-rescan** — Re-run Concord to verify drift is resolved (depends on apply-fixes)

### Dispatch template location:
Could be defined as a workflow template in Dispatch's template registry.

---

## 4. What MCP Should Expose

MCP could expose Concord as tools for AI agents:

### MCP Tool: `concord_scan`
- **Description:** Scan a repository for artifact drift and alignment issues
- **Parameters:** `dir` (string, required), `format` (enum: markdown, json), `check` (string, optional — specific check to run)
- **Returns:** Drift report in requested format
- **Security:** Read-only filesystem access, constrained to allowed directories

### MCP Tool: `concord_report`
- **Description:** Generate a drift report for the current working directory
- **Parameters:** `format` (enum: markdown, json)
- **Returns:** Structured drift report

### MCP Resource: `concord://drift-report`
- **Description:** Latest Concord drift report for the project
- **Returns:** Markdown or JSON report

### Integration point:
Concord could be registered as a tool in `mcp-server.json` under `tools.registry`.

---

## 5. What Kujo Core Should Provide

### Already available:
- `kujo run` for script execution
- `kujo init` for project scaffolding
- `kujo test` for running tests
- `execute()` / `execute_status()` for shelling out
- File I/O, JSON, string, regex built-ins
- Module system with `from X import Y`

### What would make Concord better:
- A standard CLI argument parsing built-in (e.g., `parse_args(schema)`)
- YAML/TOML parsing built-ins (currently need Python for spec files)
- A standard version comparison utility
- A standard Markdown heading/code-block extractor

### Workaround strategy:
- Manual arg parsing (same pattern as PatchBrief and ShipCheck)
- Regex-based extraction from YAML/TOML for basic fields (name, version, description)
- Simple string comparison for versions
- Regex-based fenced-code and heading extraction from Markdown

---

## 6. What Kennel Should Eventually Package

### kennel.toml for Concord
```toml
[package]
name = "concord"
version = "0.1.0"
description = "Artifact drift and alignment checker for Kujo ecosystem projects."
license = "MIT"
authors = ["Robert DeVore <me@robertdevore.com>"]
repository = "https://github.com/kujolang/concord"
keywords = ["kujo", "drift", "alignment", "developer-tools", "dogfood"]
categories = ["developer-tools"]
readme = "README.md"

[package.status]
stage = "experimental"
stability = "early"
public_api = false
notes = "MVP dogfood build. Not yet ready for production use."

[kujo]
minimum_version = "0.1.0"
entry = "concord.kujo"
sources = ["src", "."]
includes = ["README.md", "tests"]
excludes = [".git", "kennel_packages", "dist", "build", "node_modules", ".dogfood"]
```

### What Kennel needs to support Concord better:
- `kennel install concord` — once Concord is published to a registry
- Kennel should validate that `entry` in kennel.toml matches the actual CLI command
- Kennel should check that `version` in kennel.toml matches changelog

---

## 7. What Scout Should Provide (Without Overlap)

Scout should provide basic artifact discovery that Concord can consume:

- **FILE_TREE.md** — Concord can use this to find relevant artifact files
- **intelligence.json** — Concord can parse this for structured file metadata

Concord should NOT:
- Duplicate Scout's file tree scanning
- Duplicate Scout's language detection
- Duplicate Scout's dependency analysis

Concord SHOULD:
- Accept Scout's output as optional input for artifact discovery
- Fall back to its own basic file detection when Scout hasn't been run

---

## 8. Where Leash Could Fit Later

Leash could be the human approval surface for Concord's fix tasks:

1. Concord detects drift and generates fix tasks
2. Fix tasks are pushed to Leash as pending approvals
3. Developer reviews on mobile, approves/rejects each fix
4. Approved fixes are applied automatically
5. Concord re-scans to verify drift is resolved

This would make the "human_approval_required" flag in Concord's JSON findings directly actionable.

---

## 9. Where Strata Could Fit Later

Strata could store drift decisions and patterns:

1. Each Concord scan creates a note in Strata with the drift report
2. When the same type of drift is detected repeatedly, Strata's AI can suggest a permanent fix
3. Source-of-truth decisions are recorded as notes for future reference
4. Drift patterns across projects can be analyzed for ecosystem-wide issues

### Example Strata integration:
```bash
concord scan --format markdown | strata-note.sh read-stdin --tags drift,concord
```

---

## 10. Structured Artifacts Concord Should Emit

### Primary outputs:
| File | Format | Description |
|------|--------|-------------|
| `concord-report.md` | Markdown | Human-readable drift report |
| `concord-report.json` | JSON | Machine-readable drift report |
| `drift-findings.json` | JSON | Individual drift findings with severity |
| `fix-tasks.md` | Markdown | Human-readable fix task cards |
| `source-of-truth-map.json` | JSON | Which artifacts are authoritative for which facts |

### JSON Finding Shape (provisional):
```json
{
  "id": "cli-docs-command-mismatch-001",
  "severity": "high",
  "confidence": "medium",
  "category": "cli-docs-alignment",
  "title": "Documented command does not appear in CLI help",
  "summary": "README documents `tool inspect`, but CLI help only lists `tool scan`.",
  "source_artifact": "README.md",
  "target_artifact": "cli-help",
  "expected": "Documented commands should exist in CLI help or command registry.",
  "actual": "`tool inspect` was documented but not found.",
  "suggested_fix": "Update README to use the current command or add the missing CLI command.",
  "human_review_required": true
}
```

### Fix Task Shape (provisional):
```markdown
## Fix Task: cli-docs-command-mismatch-001

**Severity:** high | **Confidence:** medium | **Review required:** yes

### Problem
README documents `tool inspect`, but CLI help only lists `tool scan`.

### Suggested Fix
Update README to use the current command or add the missing CLI command.

### Affected Files
- `README.md` (line ~45)
- `src/cli.kujo`

### Validation
Run `concord scan` after fix to verify drift is resolved.
```

---

## 11. Concord Command Surface (Proposed)

| Command | Description |
|---------|-------------|
| `scan` | Run all drift checks and produce a full report |
| `check <category>` | Run a specific check category (cli-docs, spec-eval, manifest, examples, versions) |
| `report` | Generate report from the last scan |
| `tasks` | Generate fix task cards from the last scan |
| `version` | Print version information |
| `help` | Print usage information |

### Options:
| Option | Description |
|--------|-------------|
| `--dir <path>` | Target directory (default: current directory) |
| `--format markdown\|json` | Output format for scan/report (default: markdown) |
| `--output <path>` | Write report to file instead of stdout |

### Exit codes:
- `0` — No drift found, or only low-severity findings
- `1` — High-severity drift found
- `2` — Error (invalid arguments, missing directory, etc.)

---

## 12. Concord Check Categories (MVP)

### CLI ↔ Docs Alignment
- Extract documented commands from README fenced code blocks
- Compare against CLI help output (if safe to run)
- Flag commands in README that don't appear in CLI help
- Flag CLI commands that aren't documented in README

### Spec ↔ Eval Alignment
- Detect Spec files and extract acceptance criteria
- Detect Eval suite files and extract check names
- Flag acceptance criteria without matching eval checks
- Flag eval checks referencing outdated artifact paths

### Manifest ↔ Docs Alignment
- Extract package name/version/description from kennel.toml
- Compare against README title/version badges/description
- Flag mismatches in name, version, or description

### Version Consistency
- Extract versions from kennel.toml, README badges, CHANGELOG.md, CLI help
- Flag inconsistencies across version locations

### Example Validity
- Extract example commands from README/docs
- Check if referenced files exist
- Check if referenced commands exist in CLI help
- Flag examples referencing missing artifacts

### Source-of-Truth Mapping
- Identify likely source of truth for each fact type
- Flag cases where no clear source of truth exists
- Flag cases where multiple sources disagree
