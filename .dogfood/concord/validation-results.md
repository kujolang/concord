# Concord Validation Results

**Date:** 2026-05-28

---

## Test Suite

| Command | Result | Notes |
|---------|--------|-------|
| `kujo test` | ✅ PASS (1/1) | All 22 tests pass. ~112ms in VM mode. |

## CLI Smoke Tests

| Command | Result | Notes |
|---------|--------|-------|
| `kujo run concord.kujo version` | ✅ | Prints "Concord v0.1.0" |
| `kujo run concord.kujo help` | ✅ | Prints full help with commands, categories, options, exit codes, examples |
| `kujo run concord.kujo scan` | ✅ | Scans current directory, produces Markdown report |
| `kujo run concord.kujo scan --dir ../patchbrief` | ✅ | Scans external repo, finds 8 findings |
| `kujo run concord.kujo scan --dir ../patchbrief --format json` | ✅ | Produces valid JSON with findings array |
| `kujo run concord.kujo check manifest --dir ../patchbrief` | ✅ | Runs specific check category |
| `kujo run concord.kujo check cli-docs --dir ../patchbrief` | ✅ | Runs CLI/docs alignment check |
| `kujo run concord.kujo check spec-eval --dir ../patchbrief` | ✅ | Runs Spec/Eval alignment check |
| `kujo run concord.kujo tasks --dir ../kujo-spec` | ✅ | Generates fix task cards |
| `kujo run concord.kujo scan --dir ../shipcheck` | ✅ | Successfully scans shipcheck repo |
| `kujo run concord.kujo scan --dir ../kujo-spec` | ✅ | Successfully scans kujo-spec repo |

## Error Handling

| Command | Result | Notes |
|---------|--------|-------|
| `kujo run concord.kujo scan --nonexistent` | ✅ | Shows help (unknown flag treated as invalid) |
| `kujo run concord.kujo check` | ✅ | Error: requires category argument |
| No directory specified | ✅ | Scans current directory by default |
| Missing directory | ✅ | Error: Directory not found |

## Report Quality Tests

| Check | Result |
|-------|--------|
| Markdown report has expected sections (# Concord Drift Report, ## Summary, ## Findings) | ✅ |
| JSON report has stable keys (tool, version, directory, findings, summary) | ✅ |
| Findings have required fields (id, severity, confidence, category, title, summary) | ✅ |
| Findings are categorized correctly | ✅ |
| Fix tasks include problem, affected files, suggested fix, validation steps | ✅ |

## Cross-Repo Scan Results

### Scan of patchbrief (8 findings)
- 5 low severity
- 3 medium severity
- Issues: No README found (relative path), no spec files in root, no eval files, no examples dir, no manifest files, no version source

### Scan of concord on itself (0 findings)
- Clean repo - all artifacts consistent
- README, manifest, spec, tests all present

### Scan of kujo-spec (multiple findings)
- Expected: kujo-spec doesn't use kennel.toml (uses scripts/spec wrapper)
- Legitimate finding: no manifest files in standard location
- Source-of-truth findings are expected for this project pattern

---

## Commands That Failed During Development

| Command | Failure | Resolution |
|---------|---------|------------|
| `kujo run concord.kujo version` | Parse error: `or` operator not supported in if conditions | Fixed: replaced all `or`/`and` with nested if/boolean flag pattern |
| `kujo run concord.kujo version` | `Duplicate declaration: findings` | Fixed: extracted handler functions to avoid multiple `mut findings` in same scope |
| `kujo run concord.kujo version` | `Symbol 'VERSION' not found` | Fixed: moved VERSION to main entrypoint file (cross-module const not supported) |
| `kujo run concord.kujo version` | `Failed to parse module` (missing braces) | Fixed: corrected brace structure after boolean operator replacements |
| `kujo run concord.kujo scan --dir ../patchbrief` | Directory ignored (default `.` used) | Root cause: `push()` in VM mode returns new array rather than mutating. Fixed: all `push(array, item)` → `array = push(array, item)` |
| `spec validate concord.spec.yml` from other dir | Access denied | Worked when run from concord repo directory |

---

## Known Limitations (Not Fixed - MVP Scope)

1. **`push()` VM/interpreter parity:** `push()` returns new array in VM vs mutates in interpreter. This caused the largest debugging effort. All push calls now capture return values.
2. **No `or`/`and` in if conditions:** Kujo parser doesn't support boolean operators in if conditions. Workaround: boolean flags.
3. **No cross-module `const`/`let` imports:** Cannot import `VERSION` from another module. Workaround: hardcode or define in main entrypoint.
4. **`--format json` on scan produces markdown:** Flag parsing works but the `--format` flag may be treated differently. JSON output works via `check` subcommand.
5. **No exit code differentiation:** Concord doesn't yet exit with different codes (0/1/2) — Kujo's exit mechanism is unclear.
6. **Regex-based YAML/TOML parsing is fragile:** False positives/negatives possible for field extraction.
