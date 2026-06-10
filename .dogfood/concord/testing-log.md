# Concord Testing Log — Ecosystem Dogfood Pass

---

## [2026-05-28 11:30] Systematic remediation pass

This pass reviewed each logged item and applied all fixes that are actionable inside Concord.

| Item | Status | Action taken |
|------|--------|--------------|
| `or`/`and` not supported in if conditions | External dependency | No language-level fix possible in this repo; Concord keeps nested-flag pattern as compatible workaround. |
| `push()` mutation parity gap | External dependency + local hardening | Ensured `arr = push(arr, item)` pattern is used consistently across Concord code paths. |
| Cannot import non-function symbols | Mitigated in-tool | Added function-based version sharing (`concord_version()`) and removed duplicated literal usage in reporter/task output modules. |
| Duplicate `mut` declarations in one function scope | Mitigated in-tool | Kept handler-function architecture in `concord.kujo` to avoid same-scope redeclaration failures. |
| `spec validate` project-scope-only behavior | External dependency | No change possible from Concord side; retained documented workaround (`cd` into target repo first). |
| Brace breakage after boolean refactors | Mitigated in-tool | Strengthened tests in `tests/concord_tests.kujo` to assert real README detection and avoid silent parser/runtime regressions. |

Additional issues found and fixed during this pass:

1. Mixed bool/int predicate return values caused false drift findings and path detection failures.
- Fix: Added `is_truthy(...)` normalization in `src/common.kujo`; updated scanner/check/main predicate handling.

2. CLI command extraction depended on executing `kujo run ... help`, which failed when system `kujo` was not the Kujo runtime.
- Fix: Replaced external execution with static source parsing in `src/scanner.kujo` (`get_cli_help_commands`).

3. Runtime process option key changed (`max_output` no longer accepted).
- Fix: Updated to supported key and then removed shell dependency in command extraction path.

Validation after fixes:

- `kujo test` passes in `kujo-concord`.
- `concord scan --dir ../patchbrief --format json` now returns stable JSON findings (no false “README missing” and no runtime crash).

---

## [2026-05-28 13:40] Continuous loop automation for all four follow-up tracks

Implemented an executable loop runner to keep the post-dogfood process continuously active:

1. Run Concord scans across a fixed repo matrix and persist Markdown/JSON outputs.
2. Append trend rows and regenerate latest cycle summary artifacts.
3. Run category regression snapshots (`cli-docs`, `manifest`, `examples`) and build gate summaries.
4. Refresh upstream issue drafts from unresolved ecosystem-level gaps.

Artifacts and controls:

- Runner: `scripts/concord_continuous_loop.sh`
- Repo matrix: `.dogfood/concord/loop/repos.txt`
- Output root: `.dogfood/concord/loop/`
- Latest summary: `.dogfood/concord/loop/trend/latest-summary.md`
- Upstream drafts: `.dogfood/concord/loop/upstream-issue-drafts.md`

Validation execution:

- `scripts/concord_continuous_loop.sh --iterations 1` completed successfully and produced a full cycle artifact set under `.dogfood/concord/loop/runs/`.
- Continuous mode launched with `--iterations 0 --sleep-seconds 900`; active runtime logs stream to `.dogfood/concord/loop/runner.log`.

---

## [2026-05-28 08:00] `or`/`and` operators not supported in if conditions

**Category:** Language gap

**What happened:** Kujo parser rejects `or` and `and` in if condition expressions. All boolean logic must use nested ifs with boolean flags.

**What I expected:** Standard boolean operators in if conditions, like most languages.

**What actually happened:** Parse errors like `Expected '{' to start if block but found Identifier("or")`. Had to restructure 30+ conditions across all source files.

**Impact:** Significant code verbosity increase. Every `if a and b` becomes:
```
mut flag := 0
if a { if b { flag = 1 } }
if flag == 1 { ... }
```

**Suggested fix:** Add `and`/`or` support to the Kujo parser for if condition expressions. P0 language gap.

---

## [2026-05-28 08:15] `push()` returns new array in VM mode, doesn't mutate

**Category:** Language gap / VM-interpreter parity

**What happened:** `push(arr, item)` returns a new array in VM mode without mutating the original. `mut arr := []` followed by `push(arr, item)` leaves arr empty. The correct pattern is `arr = push(arr, item)`.

**What I expected:** `push()` to mutate in place for `mut` arrays, similar to most languages.

**What actually happened:** The test suite passed (interpreter handles push differently), but the main script produced empty arrays. Took extensive debugging to identify. All ~50 push calls across 10+ files needed `arr = push(arr, item)` pattern.

**Impact:** This was the single largest debugging effort in this dogfood pass. Caused `--dir` flag to be silently ignored and all check functions to return empty findings.

**Suggested fix:** Make `push()` mutation behavior consistent between VM and interpreter. P0 parity issue.

---

## [2026-05-28 08:30] Cannot import non-function symbols across modules

**Category:** Language gap

**What happened:** `VERSION` defined in `src/common.kujo` cannot be imported via `from src.common import VERSION` in `concord.kujo`. Only functions can be imported.

**What I expected:** Constants and variables should be importable across modules.

**What actually happened:** Runtime error: `Symbol 'VERSION' not found in module 'src.common'`. Had to inline the version string in every file that needed it.

**Impact:** Code duplication for constants. Forces all constants to be defined in the main entrypoint.

**Suggested fix:** Support `export const` or `export let` for cross-module constant/variable imports. P1 language gap.

---

## [2026-05-28 08:45] Multiple `mut` declarations in same function trigger duplicate errors

**Category:** Language gap / VM compilation quirk

**What happened:** Multiple `mut findings := ...` declarations in different if-blocks of `main()` caused `Duplicate declaration in the same scope: findings`. The VM compiler treats the entire function body as a single scope regardless of block boundaries.

**What I expected:** Block-scoped variable declarations, where each if-block has its own scope.

**What actually happened:** Compilation error. Had to extract each if-block into a separate handler function.

**Impact:** Forced architectural restructuring (handler functions) that wouldn't be needed in most languages.

**Suggested fix:** Implement proper block scoping for `mut`/`let` declarations. P1.

---

## [2026-05-28 09:00] Spec validation is project-scoped only

**Category:** CLI friction

**What happened:** `spec validate` rejects files outside the current working directory. Must cd into the target repo to validate.

**What I expected:** Read-only operations like validate should accept absolute paths.

**What actually happened:** `Access to path outside project denied`.

**Impact:** Minor inconvenience. Workaround: cd into the project first.

**Suggested fix:** Allow read-only spec operations (validate, render, export) on paths outside current directory. P3.

---

## [2026-05-28 09:15] Brace matching issues after automated boolean operator fixes

**Category:** Agent friction / Tool limitation

**What happened:** After replacing `and`/`or` with nested if blocks, several files had broken brace structures. The structural edits didn't always maintain correct nesting.

**What I expected:** Straightforward refactoring.

**What actually happened:** Multiple iterations of compile-parse-error → fix braces → compile-parse-error were needed. Files `cli_docs.kujo`, `example_validity.kujo`, and `spec_eval.kujo` required several rounds of fixes.

**Impact:** Slowed development significantly. The parse errors are incremental (one file at a time) rather than reporting all issues at once.

**Suggested fix:** Improve parser error reporting to show all parse errors, not just the first one in each file.

---

## [2026-05-28 09:30] Kujo CLI now has `kujo init` — ecosystem improvement!

**Category:** DX win

**What happened:** `kujo init` was noted as missing in the PatchBrief pass but is now available. This is a confirmed ecosystem improvement.

**What I expected:** Manual project scaffolding.

**What actually happened:** `kujo init` is now a built-in command.

**Impact:** Positive. The ecosystem is improving. However, `kujo init` was not used in this pass since the project was scaffolded manually following existing patterns.

---

## [2026-05-28 09:45] Overall Assessment

**The Kujo ecosystem is functional but VM/interpreter parity gaps cause significant friction.**

The three most impactful issues:
1. `push()` mutation semantics differ between VM and interpreter — this consumed the most debugging time
2. `or`/`and` not supported in if conditions — forced verbose code patterns
3. No cross-module constant imports — forced code duplication

The three best aspects:
1. `kujo test` is fast and reliable
2. The module system with `from X import Y` works well for functions
3. `execute()` for shell commands works reliably
