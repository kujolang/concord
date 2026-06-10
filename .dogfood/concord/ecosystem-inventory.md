# Kujo Ecosystem Inventory — Concord Dogfood Pass

**Date:** 2026-05-28
**Purpose:** Understand what exists, what is usable, and what is missing before building Concord.
**Previous passes:** PatchBrief (diff→brief), ShipCheck (release readiness), Trail (onboarding verification)

---

## 1. Repositories Found

### Core Language & Runtime

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo** | `2026/kujo` | Core Kujo language and runtime. Rust-based, VM-first with interpreter fallback. Now has `kujo init`, `kujo package-add`, `kujo package-install`, `kujo package-publish` built into CLI. | Pre-1.0. Active development. |

### Package Management

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo-kennel** | `2026/kujo-kennel` | Package manager. CLI at `kennel.kujo`. Supports full dependency lifecycle, hosted registry, trust policies, semver range solver. `kennel.toml` format used by many ecosystem repos. | Available. |

### Task & Specification

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo-spec** | `2026/kujo-spec` | Structured task definition format (YAML/TOML/JSON). CLI via `scripts/spec` bash wrapper. Has JSON Schema at `schema/spec.schema.json`. | Available (v0.1.0). |

### Evaluation & Validation

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo-eval** | `2026/kujo-eval` | Evaluation framework. 27 deterministic checks, 5 report formats, snapshot testing, retry, CI-ready. CLI via `main.kujo`. | Production-ready (v0.3.1). |

### Codebase Intelligence

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo-scout** | `2026/kujo-scout` | Codebase intelligence scanner. Produces FILE_TREE.md, intelligence.json, AGENTS.md, CHECKLIST.md, llms.txt. Detects languages, dependencies, routes, security smells. Also has Kennel-compatible output modes. | Available (v1.0.0). |

### Workflow Orchestration

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo-dispatch** | `2026/kujo-dispatch` | Workflow orchestration engine. DAG-style steps, retries, approval gates, handoffs, state persistence, traces, reports. CLI at `dispatch.kujo`. | Available (v0.1.0). |

### MCP Server

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo-mcp** | `2026/kujo-mcp` | MCP server framework. Plugin-style tool/resource registration, path guards, rate limits, auth. Server at `server.kujo`. | Available. |

### AI/Agent SDKs

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo-ai-sdk** | `2026/kujo-ai-sdk` | Provider-agnostic AI SDK. OpenAI-compatible chat/embeddings with normalized contracts. | Available. |
| **kujo-agents-sdk** | `2026/kujo-agents-sdk` | Agent runtime primitives (runner, tools, security, memory, retrieval, handoffs, tracing). | Foundational scaffolding. |

### Applications & Ecosystem Tools

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **kujo-ai-chat** | `2026/kujo-ai-chat` | Multi-provider AI chat web app. Node.js + Kujo SDK bridge. | Production-ready. |
| **kujo-cms** | `2026/kujo-cms` | Headless CMS API. Content types, taxonomies, entries, media, auth. | Available. |
| **kujo-leash** | `2026/kujo-leash` | Human-in-the-loop mobile control plane. Rust daemon + Kujo policy + Kotlin Android app. | Available. |
| **kujo-rag** | `2026/kujo-rag` | RAG (Retrieval-Augmented Generation) system. | Available. |
| **kujo-watchdog** | `2026/kujo-watchdog` | Monitoring/watchdog service with dashboard. | Available. |
| **kujo-ssg** | `2026/kujo-ssg` | Static site generator. | Available. |
| **kujo-crud-api-showcase** | `2026/kujo-crud-api-showcase` | CRUD API showcase/reference. | Available. |
| **kujo-trail** | `2026/kujo-trail` | Empty repo (git init only, no files). Intended for onboarding/HOWTO verification dogfood tool. | Not yet built. |

### Dogfood Showcase Tools

| Repo | Path | Description | Status |
|------|------|-------------|--------|
| **patchbrief** | `2026/patchbrief` | Git diff → implementation brief. 4 subcommands, 17 tests. | MVP complete. |
| **shipcheck** | `2026/shipcheck` | Release-readiness scanner. 16 checks, 4 categories. | MVP complete. |
| **concord** | `2026/kujo-concord` | This project — artifact drift & alignment tool. | Just initialized. |

### User Applications (Non-Kujo)

| Repo | Path | Description |
|------|------|-------------|
| **strata** | `2026/strata` | Local-first desktop knowledge app for Markdown notes. Electron/TypeScript. HTTP API at `127.0.0.1:3939`. |

---

## 2. Key Ecosystem Characteristics

### Tool Structure Pattern (from PatchBrief, ShipCheck, Scout, Dispatch)

1. Single entrypoint script (e.g., `concord.kujo`)
2. Library modules in `src/` (e.g., `src/scanner.kujo`, `src/reporter.kujo`)
3. Manual CLI arg parsing using `args()` builtin
4. `kennel.toml` for package metadata
5. `kujo.toml` for Kujo project configuration
6. Tests in `tests/` directory
7. `.dogfood/concord/` for ecosystem testing docs
8. Spec file at `concord.spec.yml` (or similar)

### Available Primitives (from Kujo standard library)

- **File I/O:** `file_exists()`, `path_is_dir()`, `list_dir()`, `read_file()`, `write_file()`, `join_path()`
- **Process:** `execute(cmd, opts)`, `execute_status(cmd)` — returns ProcessResult with exitcode, stdout, stderr
- **JSON:** `parse_json()`, `to_json()`, `to_json_pretty()`
- **String:** `contains()`, `starts_with()`, `ends_with()`, `split()`, `trim()`, `to_lower()`, `replace()`, `to_string()`, `to_int()`
- **Array:** `push()`, `len()`, `map()`, `filter()`
- **Dict:** `keys()`, `has_key()`
- **Regex:** `regex_match()`, `regex_find_all()`
- **CLI:** `args()` — returns user arguments (NOT including script name)

### Known Language Quirks (from previous dogfood passes)

1. `contains()`/`starts_with()`/`ends_with()`/`has_key()` return `int` (1/0), not `bool`
2. `let` bindings silently accept `=` reassignment but don't update the value — use `mut` with `:=`
3. Dict access uses `["key"]`, struct access uses `.field` — different syntaxes
4. `push()` returns a new array rather than mutating in place
5. `args()[0]` is the first user argument, not the script path
6. No built-in pretty-printer for JSON — use `to_json_pretty()` (may exist now)
7. `to_string()` is needed before concatenating non-string values

### Recent CLI Additions (since PatchBrief pass)

- `kujo init` — project scaffolding (WAS missing, now exists!)
- `kujo package-add` — dependency management from CLI
- `kujo package-install` — validate dependencies
- `kujo package-publish` — preview package publish metadata

---

## 3. What Concord Should Do (Gap Analysis)

### Existing Tools and Their Scope

| Tool | Scope | Does NOT Cover |
|------|-------|----------------|
| **PatchBrief** | Git diff → implementation briefs | Cross-artifact consistency |
| **ShipCheck** | Release-readiness checks | Artifact alignment/drift |
| **Trail** | Onboarding/HOWTO verification | Doesn't exist yet |
| **Scout** | Codebase intelligence (files, deps, routes, security) | Artifact alignment detection |
| **Spec** | Task definition format | Validation that spec matches reality |
| **Eval** | Deterministic checks | Validation that checks match current artifacts |
| **Dispatch** | Workflow orchestration | Workflow validation |
| **Kennel** | Package management | Package metadata consistency |

### The Gap Concord Fills

**Concord checks whether the important artifacts in a repo agree with each other.**

No existing tool answers: "Do the code, CLI, docs, examples, Spec files, Eval checks, schemas, package metadata, and release artifacts still describe the same product?"

### Specific Drift Categories Concord Should Detect

1. **CLI ↔ Docs drift:** README says `tool scan` but CLI exposes `tool inspect`
2. **Spec ↔ Eval drift:** Spec requires JSON output but Eval only checks Markdown output
3. **Manifest ↔ Docs drift:** Package name/version differs between kennel.toml and README
4. **Examples ↔ Reality drift:** Example commands reference flags that no longer exist
5. **CLI ↔ CLI help drift:** Commands in help don't match what's documented
6. **Version drift:** Different versions across manifest, README, changelog, CLI help
7. **Artifact path drift:** Docs mention generated files that are never produced
8. **Source-of-truth ambiguity:** Multiple files claim to be authoritative for the same fact

---

## 4. Concord Feasibility Assessment

### What can be done with existing tools:
- **Spec:** Define the Concord task formally. Create a spec file following the existing conventions.
- **Eval:** Validate Concord's behavior (report shape, drift detection accuracy, exit codes).
- **Scout:** Could be used for basic artifact discovery (finding files), but Concord's core logic must be custom.
- **Dispatch:** Could orchestrate Concord scan → report → fix-task generation.
- **Kennel:** Could eventually package Concord for distribution.
- **MCP:** Could expose Concord as an MCP tool for agents to check drift in repos they work on.

### What must be built from scratch:
- Core drift detection logic (CLI/docs comparison, spec/eval comparison, manifest/docs comparison)
- Markdown/JSON report generation
- Fix-task generation
- Basic CLI argument parsing
- Fenced-code extraction from Markdown
- CLI help output parsing
- Version extraction from various file formats

### What is pragmatically impossible with current ecosystem:
- No YAML/TOML parsing in Kujo core — would need to shell out to Python or use regex patterns for spec files
- No built-in semantic diff — approximate matching only
- No AST-level code analysis to verify CLI commands match implementation

---

## 5. Key Gaps Relevant to Concord

### Missing Primitives

| Gap | Impact on Concord | Priority |
|-----|-------------------|----------|
| No standard CLI arg parser | Must write manual arg parsing (boilerplate) | P1 |
| No YAML/TOML parser in Kujo | Can't natively parse Spec files or kennel.toml | P1 |
| No built-in Markdown parser | Must use regex for extracting fenced code, headings, etc. | P2 |
| No standard version comparison | Must implement semver-like comparison manually | P2 |
| No `kujo new` ecosystem subcommand | Still no ecosystem-standard project template | P2 |

### Ecosystem Convention Gaps

| Gap | Impact on Concord | Priority |
|-----|-------------------|----------|
| No standard CLI metadata format | Can't machine-read command lists from most tools | P1 |
| No standard artifact output contract | Hard to know what files a tool should generate | P1 |
| No spec↔eval linking convention | Can't automatically verify spec criteria have matching eval checks | P0 |
| No manifest↔docs alignment convention | No standard for keeping package metadata in sync with documentation | P1 |
| No version consistency convention | Each repo may store version in different places | P2 |
| No source-of-truth declaration convention | Can't automatically determine which artifact is authoritative | P1 |

### Documentation Gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| No unified ecosystem architecture doc | Hard to understand how tools compose | P2 |
| No artifact alignment guide | Tools drift because there's no guidance on keeping them aligned | P1 |
| No cross-tool contract documentation | Spec, Eval, Scout, Dispatch, Kennel don't document their expected integration points | P1 |

---

## 6. Previous Dogfood Pass Learnings

### From PatchBrief:
- Spec tool works well for task definition
- `kujo test` is fast and reliable
- `execute()` built-in works for git commands
- Module system with `export` works
- `contains()` returns int (not bool) — use `== 1` comparisons
- No CLI framework — manual arg parsing is boilerplate
- `args()` doesn't include script name

### From ShipCheck:
- `let` vs `mut` is a footgun (silent no-op on reassignment)
- Dict vs struct access boundary is confusing
- Interpreter-only diagnostics hide bugs from VM mode
- `push()` returns new array (not mutation)
- Kennel manifest format is well-designed

### New Since Those Passes:
- `kujo init` exists now (was a pain point in both previous passes)
- `kujo package-add/install/publish` exist now
- `kujo-trail` repo initialized but empty — the third dogfood pass is just getting started

---

## 7. Concord-Specific Observations

### What Concord should NOT overlap with:
- **Scout:** File tree scanning, language detection, dependency analysis, route discovery, security scanning
- **ShipCheck:** Release readiness gates, checklist generation, release note drafting
- **PatchBrief:** Git diff summarization, test suggestion, handoff notes
- **Trail:** Onboarding verification, HOWTO execution

### What Concord SHOULD focus on:
- Cross-artifact comparison (multiple files checked against each other)
- Drift detection (differences between what artifacts claim)
- Source-of-truth identification (which artifact is authoritative)
- Severity classification of drift findings
- Fix-task generation for actionable drift
- Structured output for downstream tools (Eval, Dispatch, MCP, Leash, Strata)
