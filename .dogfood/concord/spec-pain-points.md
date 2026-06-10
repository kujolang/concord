# Spec Tool Pain Points — Concord Dogfood Pass

**Date:** 2026-05-28

---

## Pain Points Encountered

### 1. Spec validation is project-scoped only

**Category:** CLI friction

**Problem:** `spec validate` rejects files outside the current working directory. This makes it impossible to validate a spec file in another repo without `cd`-ing there first. The error message says "Spec files must be within the current project directory" but this is a validation CLI, not a write operation.

**Impact:** Inconvenient for cross-repo workflows where an agent is working from a different directory.

**Suggested fix:** Allow `spec validate <absolute-path>` when the operation is read-only (validate, render, export-agent-context). Only restrict writes.

---

### 2. Spec requires Python for YAML/TOML parsing

**Category:** Missing primitive

**Problem:** The spec CLI is a bash wrapper that delegates YAML/TOML parsing to Python scripts (`spec_yaml_to_json.py`, `spec_toml_to_json.py`). Kujo itself has no native YAML/TOML parsing. This means `spec validate` has a hidden Python dependency.

**Impact:** Kujo can't validate its own spec format natively. This is a circular dependency — Kujo tools need Python to validate their specs.

**Suggested fix:** Add native YAML/TOML parsing to the Kujo standard library, or at least provide a `parse_yaml()` / `parse_toml()` built-in.

---

### 3. No `spec` subcommand in `kujo` CLI

**Category:** Integration gap

**Problem:** Spec is a separate repo with a bash wrapper script. There is no `kujo spec` subcommand. Users must clone kujo-spec and set up the PATH manually.

**Impact:** New users won't discover Spec. The spec tool feels like a third-party addon rather than a core ecosystem primitive.

**Suggested fix:** Integrate spec as `kujo spec` or at minimum add a `kujo spec` command that delegates to the installed spec tool.

---

### 4. Spec schema doesn't include drift/alignment fields

**Category:** Weak contract

**Problem:** The spec schema has no fields for artifact alignment rules, drift severity definitions, or source-of-truth declarations. These are concepts Concord needs but the spec format doesn't support natively.

**Impact:** Concord's spec uses `risks` and free-text fields to describe drift concerns, but these are not machine-readable.

**Suggested fix:** Consider adding optional `artifact_alignment` and `drift_rules` sections to the spec schema in a future version.

---

## What Worked Well

1. **`spec validate` is fast and clear** — validation passed on first try once run from the correct directory
2. **Schema is well-designed** — all fields we needed (name, goal, background, scope, non_goals, acceptance_criteria, eval_requirements, risks, dependencies, review_expectations, human_approval_points) are available
3. **YAML format is clean and readable**
4. **The spec tool's JSON Schema is thorough** — good validation of field types and constraints
