# Concord Repository Hardening Audit

## Repository

- Repository: `concord`
- Branch: `main`
- Starting SHA: `8d5ee11e0035ad7469aabe2fa8eb887d1c593c1f`
- Ending implementation SHA: `da3fe4462d52cddd39a0c989e6adaae6c4116cfb`
- Purpose: local, rule-based drift detection across repository CLI, documentation, Spec, Eval, manifest, version, example, and source-of-truth artifacts.
- Important dependencies and integrations: Kujo runtime, optional Git repository metadata, `jq` plus standard shell utilities for the continuous loop, Kennel manifests, Kujo Spec, and Kujo Eval metadata. The scanner has no network or AI dependency and does not execute target-repository code.

The report itself is committed after the implementation SHA, so the final repository SHA is recorded in the engineering receipt rather than embedded recursively here.

## Baseline

The initial wrapper correctly rejected an unset `KUJO_RUNTIME_BIN`. With `KUJO_RUNTIME_BIN=/Users/robertdevore/.local/bin/kujo`:

| Check | Baseline result |
| --- | --- |
| `./kujo test` | Passed 1/1 suites; test runtime 57.98 ms; wall time 0.30 s |
| `./kujo run concord.kujo -- scan` | Exit 0; no findings; wall time 2.37 s |
| `./kujo run concord.kujo -- scan --format json` | Exit 0; valid JSON; no findings; wall time 2.23 s |
| `./kujo run concord.kujo -- check cli-docs` | Exit 0; no findings |
| Invalid scan option | Exit 2 with a concise usage error |
| Missing output parent | Exit 4 with a Kujo VM stack trace, outside the documented CLI exit contract |
| Continuous loop against a fixture with high drift | Misclassified the successful scan as `scan_failed`, discarded its finding counts, and recorded one synthetic critical failure |

Relevant measured dimensions were CLI behavior, loop result integrity, output failure semantics, one-shot wall time, deterministic output hashes, and retained trend size. No network, concurrency, persistent database, large-memory, model, prompt, token, package dependency tree, build artifact, or binary-size benchmark applies to this repository.

## Findings

| ID | Priority | Area | Finding | Evidence | Action | Status |
| -- | -------- | ---- | ------- | -------- | ------ | ------ |
| CON-HARD-001 | P1 | Correctness | The continuous loop treated Concord's documented exit 1 for high/critical findings as a scanner crash, discarded valid JSON counts, and stopped later artifact generation. | High-drift fixture produced `status=scan_failed`, zero findings, and one synthetic critical failure. | Accept scan exits 0 and 1 as completed scans; retain the report and finding counts. | Fixed and regression-tested |
| CON-HARD-002 | P1 | Resource safety | Negative or malformed iteration values could produce an accidental infinite loop or shell arithmetic failure; trend history was unbounded. | Argument parsing dereferenced `$2` without checks, accepted negative values, and appended forever to `scan-trend.jsonl`. | Validate all values, require non-negative integers, and cap trend history at 10,000 rows by default with an explicit unlimited override. | Fixed and regression-tested |
| CON-HARD-003 | P1 | Security/output integrity | Repository-controlled paths and finding text could inject terminal control bytes or Markdown structure into human-readable output. | Markdown paragraphs and CLI check output interpolated raw finding values; file and manifest names are target-repository controlled. | Make control bytes visible and escape Markdown text/code contexts; preserve raw values only in JSON where serialization escapes them. | Fixed and regression-tested |
| CON-HARD-004 | P1 | Failure semantics | Output write failures escaped as Kujo VM errors with exit 4 and a stack trace instead of the documented CLI error contract. | Writing below a missing parent returned `[KUJOVM001]` and exit 4. | Catch write failures, emit one actionable line, and return exit 2 from `scan`, `check`, `report`, and `tasks`. | Fixed and verified |
| CON-HARD-005 | P2 | Parsing correctness | CLI command checks used substring matching, and YAML field extraction could match suffix keys such as `display_name` for `name`. | `rescan` could satisfy `scan`; YAML regex was not line/key anchored. | Compare exact command tokens and entry filenames; anchor YAML keys. | Fixed and regression-tested |
| CON-HARD-006 | P2 | Data integrity | Loop records were assembled with `printf` and raw paths, which could produce invalid JSON. | Repository slug and path were interpolated without JSON escaping. | Generate records with `jq --arg`/`--argjson`. | Fixed and regression-tested with quotes and a pipe in the fixture path |
| CON-HARD-007 | P2 | Determinism | Repositories with the same basename could overwrite each other's scan, task, and check artifacts; cycles in the same second could reuse a run directory. | Artifact paths used only `basename`; run paths used second-resolution timestamps. | Prefix artifacts with matrix position and create unique run directories. | Fixed and regression-tested |
| CON-HARD-008 | P2 | Documentation | `report` claimed to use a previous scan although it reruns all checks, and CLI/docs comparison was described as parsing executed help output although it reads source. | README/help wording differed from implementation. | Correct the command and scanner descriptions and document loop bounds and tests. | Fixed |
| CON-HARD-009 | P2 | CI | The shell workflow had no repository-local regression test in CI. | Existing workflow only guarded generated artifact commits. | Add a deterministic fake-runtime loop test and run it in GitHub Actions. | Fixed |

## Changes Implemented

### Human-readable output hardening

- Problem: untrusted target-repository text crossed terminal and Markdown output boundaries unchanged.
- Root cause: report generation assumed finding strings and paths were safe display content.
- Implementation: centralized terminal control sanitization and Markdown text/code escaping; applied it to reports, task cards, errors, receipts, and plain check output.
- Files: `src/common.kujo`, `src/reporter.kujo`, `src/fix_tasks.kujo`, `concord.kujo`.
- Tests: terminal escape, structural newline, HTML boundary, and table-cell regressions in `tests/concord_tests.kujo`.
- Compatibility: JSON values and schema are unchanged. Human-readable Markdown now escapes unsafe content and uses HTML `<code>` elements for paths.

### CLI parsing and failure contracts

- Problem: source comparisons accepted substrings, field parsing could select the wrong YAML key, and write failures violated documented exit behavior.
- Root cause: loose regex/token checks and uncaught filesystem write errors.
- Implementation: exact command/entry tokens, anchored YAML keys, and caught output writes that return exit 2.
- Files: `src/scanner.kujo`, `src/checks/cli_docs.kujo`, `concord.kujo`.
- Tests: exact entry, substring rejection, exact YAML key, and manual CLI write-failure verification.
- Compatibility: successful CLI commands, JSON, config, and normal exit codes are unchanged. Failed output writes intentionally change from runtime exit 4 to documented usage/config exit 2.

### Continuous-loop reliability and resource bounds

- Problem: valid high-drift scans were discarded; malformed limits, unsafe JSON construction, filename collisions, timestamp collisions, and unlimited trends weakened long-running operation.
- Root cause: the loop conflated scan severity with process failure and had no explicit input or retention model.
- Implementation: preserve exit 1 reports, validate options/dependencies, use JSON-safe record construction, unique run/artifact names, Markdown-safe summaries, and bounded trend retention.
- Files: `scripts/concord_continuous_loop.sh`, `tests/continuous_loop_tests.sh`, `.github/workflows/kujo-tool-artifacts-guard.yml`.
- Tests: two-cycle fake-runtime test covering high findings, strict gating, unique artifacts, JSON/path escaping, trend truncation, missing values, and negative values.
- Compatibility: `--iterations 0` remains the explicit infinite mode. New `--trend-max-records 0` preserves unbounded history when intentionally requested. Generated run directory and per-repository artifact names are more specific; consumers that hardcode prior names must discover artifacts from the run directory instead.

## Performance & Efficiency

| Dimension | Before | After | Assessment |
| --- | --- | --- | --- |
| Trend retention | Unbounded JSONL growth | 10,000 rows by default; configurable; `0` explicitly unlimited | Material resource bound |
| Failed high-drift cycle | Valid JSON discarded and downstream Markdown/tasks skipped | One scan result retained and downstream artifacts generated | Avoids false failure/retry work and preserves evidence |
| Run/artifact collisions | Possible at second resolution or duplicate basenames | Unique run directories and indexed artifact names | Deterministic retention |
| Output-write failure | Multi-line VM stack trace | One-line actionable error | Lower default error volume |
| One-shot scan wall time | Markdown 2.37 s; JSON 2.23 s | Post-change observed 2.35–2.60 s in repeated JSON runs; verification samples varied up to 2.80 s | No runtime speedup claimed; safeguards add small work and wrapper/compiler variance dominates |
| Dependencies | Kujo; optional Git; shell/`jq` for loop | Unchanged | No dependency growth |

No token/context benchmark applies: Concord contains no model integration, prompt, MCP schema, or agent-message loop. Documentation remains progressive and command-focused.

## Security

Reviewed trust boundaries:

- CLI argument parsing and output paths.
- Target-repository file names and file contents.
- Markdown, terminal, JSON, and shell-generated report boundaries.
- The repo-local Kujo wrapper and user-selected runtime executable.
- Continuous-loop repository matrices, generated file names, records, and summaries.
- CI scripts and Git revision inputs.

Fixed repository-controlled terminal/Markdown injection and JSON record corruption. Concord still deliberately reads complete candidate metadata/docs files and uses regex-based parsing; it does not execute target-repository CLI help or make network requests. The user-selected Kujo runtime remains an intentional executable trust decision. No credential handling, network listener, unsafe deserialization, archive extraction, authentication, shared mutable service state, or concurrent worker pool exists here.

## Compatibility

- Public APIs: no exported JSON field or supported command removed. New utility exports are additive.
- CLI: successful command syntax is unchanged. Output write failures now return documented exit 2. Human-readable unsafe content is escaped.
- File formats/schemas: JSON report and finding keys are unchanged. Continuous-loop trend records retain their fields.
- Generated paths: run directory and artifact filenames are now unique and therefore differ from the previous naming convention.
- Config: no existing config key changed.
- Environment: optional `CONCORD_LOOP_ROOT` is additive for isolated/test runs.
- External consumers: consumers of JSON remain compatible; consumers that hardcode generated loop filenames should enumerate the current run directory.

## Cross-Repository Follow-Ups

No new cross-repository change is required for this hardening pass. Existing ecosystem limitations already recorded by Concord's dogfood workflow remain outside this repository and were not modified.

## Remaining Work

- **P0:** none known.
- **P1:** none known.
- **P2:** consider recursive, bounded discovery for nested docs/examples only after representative target-repository fixtures establish expected behavior.
- **P3:** consider consolidating duplicated Markdown assembly helpers if Kujo gains importable non-function constants and the change remains clear.
- **Needs more evidence:** maximum target artifact size, acceptable regex false-positive rate, and whether structured YAML/TOML parsing would justify dependency or runtime cost.
- **Not worth changing:** caching repeated reads in the current small, single-process scanner without evidence that file I/O, rather than Kujo startup/compilation, is the bottleneck.

## Verification Receipt

| Command | Result |
| --- | --- |
| `KUJO_RUNTIME_BIN=/Users/robertdevore/.local/bin/kujo ./kujo test` | Passed 1/1 suites |
| `bash tests/continuous_loop_tests.sh` | Passed |
| `bash -n kujo scripts/concord_continuous_loop.sh tests/continuous_loop_tests.sh .github/scripts/check-kujo-tool-artifacts.sh` | Passed |
| `KUJO_RUNTIME_BIN=/Users/robertdevore/.local/bin/kujo ./kujo run concord.kujo -- scan` | Exit 0; no findings |
| `KUJO_RUNTIME_BIN=/Users/robertdevore/.local/bin/kujo ./kujo run concord.kujo -- scan --format json` | Exit 0; valid JSON; no findings |
| `KUJO_RUNTIME_BIN=/Users/robertdevore/.local/bin/kujo ./kujo run concord.kujo -- check all` | Exit 0; no findings |
| Missing output-parent integration check | Exit 2; concise error; passed expected behavior |
| `bash .github/scripts/check-kujo-tool-artifacts.sh HEAD~1 HEAD` | Passed |
| `git diff --check` | Passed |

The final verification after this report commit reruns the same repository tests and scans; the engineering receipt records the final SHA and push state.
