#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOOP_ROOT="${CONCORD_LOOP_ROOT:-$REPO_ROOT/.dogfood/concord/loop}"
RUNS_DIR="$LOOP_ROOT/runs"
TREND_DIR="$LOOP_ROOT/trend"
TREND_FILE="$TREND_DIR/scan-trend.jsonl"
LATEST_SUMMARY_FILE="$TREND_DIR/latest-summary.md"
ISSUE_DRAFTS_FILE="$LOOP_ROOT/upstream-issue-drafts.md"

REPOS_FILE="$LOOP_ROOT/repos.txt"
ITERATIONS=1
SLEEP_SECONDS=300
STRICT_GATE=0
TREND_MAX_RECORDS=10000
CYCLE_GATE_FAILED="false"

if [[ -n "${KUJO_BIN:-}" ]]; then
	KUJO_CMD="$KUJO_BIN"
elif [[ -x "$REPO_ROOT/kujo" ]]; then
	KUJO_CMD="$REPO_ROOT/kujo"
else
	KUJO_CMD="kujo"
fi

usage() {
	cat <<EOF
Usage: scripts/concord_continuous_loop.sh [options]

Options:
  --repos-file PATH      Repo matrix file (default: .dogfood/concord/loop/repos.txt)
  --iterations N         Number of loop iterations (default: 1, 0 = infinite)
  --sleep-seconds N      Delay between iterations for infinite/multi-run loops (default: 300)
  --strict-gate          Exit non-zero when any cycle has high/critical findings
  --trend-max-records N  Retain at most N trend rows (default: 10000, 0 = unlimited)
  --kujo-bin PATH        Kujo runtime binary override
  -h, --help             Show this help
EOF
}

require_option_value() {
	local option="$1"
	local value="${2:-}"
	if [[ -z "$value" || "$value" == --* ]]; then
		echo "Option requires a value: $option" >&2
		usage >&2
		exit 2
	fi
}

require_non_negative_integer() {
	local option="$1"
	local value="$2"
	if [[ ! "$value" =~ ^[0-9]+$ ]]; then
		echo "Option must be a non-negative integer: $option ($value)" >&2
		exit 2
	fi
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--repos-file)
			require_option_value "$1" "${2:-}"
			REPOS_FILE="$2"
			shift 2
			;;
		--iterations)
			require_option_value "$1" "${2:-}"
			ITERATIONS="$2"
			shift 2
			;;
		--sleep-seconds)
			require_option_value "$1" "${2:-}"
			SLEEP_SECONDS="$2"
			shift 2
			;;
		--strict-gate)
			STRICT_GATE=1
			shift
			;;
		--trend-max-records)
			require_option_value "$1" "${2:-}"
			TREND_MAX_RECORDS="$2"
			shift 2
			;;
		--kujo-bin)
			require_option_value "$1" "${2:-}"
			KUJO_CMD="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1" >&2
			usage
			exit 2
			;;
	esac
done

require_non_negative_integer "--iterations" "$ITERATIONS"
require_non_negative_integer "--sleep-seconds" "$SLEEP_SECONDS"
require_non_negative_integer "--trend-max-records" "$TREND_MAX_RECORDS"

if ! command -v "$KUJO_CMD" >/dev/null 2>&1; then
	echo "Kujo command not found or not executable: $KUJO_CMD" >&2
	exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
	echo "Required command not found: jq" >&2
	exit 2
fi

if [[ ! -f "$REPOS_FILE" ]]; then
	echo "Repos file not found: $REPOS_FILE" >&2
	exit 2
fi

mkdir -p "$RUNS_DIR" "$TREND_DIR"
touch "$TREND_FILE"

append_record() {
	local records_file="$1"
	local timestamp="$2"
	local repo="$3"
	local path="$4"
	local status="$5"
	local total="$6"
	local highest="$7"
	local critical="$8"
	local high="$9"
	local medium="${10}"
	local low="${11}"

	jq -cn \
		--arg timestamp "$timestamp" \
		--arg repo "$repo" \
		--arg path "$path" \
		--arg status "$status" \
		--argjson total_findings "$total" \
		--arg highest_severity "$highest" \
		--argjson critical "$critical" \
		--argjson high "$high" \
		--argjson medium "$medium" \
		--argjson low "$low" \
		'{timestamp: $timestamp, repo: $repo, path: $path, status: $status, total_findings: $total_findings, highest_severity: $highest_severity, critical: $critical, high: $high, medium: $medium, low: $low}' \
		>> "$records_file"
}

markdown_cell() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//|/\\|}"
	value="${value//$'\r'/\\r}"
	value="${value//$'\n'/\\n}"
	value="${value//</\\<}"
	value="${value//>/\\>}"
	printf '%s' "$value"
}

build_issue_drafts() {
	local out_file="$1"
	local ts
	ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
	cat > "$out_file" <<EOF
# Concord Upstream Issue Drafts

Generated: $ts

These drafts track unresolved ecosystem gaps discovered in Concord dogfooding.

## Draft 1: Support boolean and/or operators in all condition contexts
- Repo: kujo
- Priority: P0
- Problem: Conditionally composed expressions require verbose nested-flag workarounds in multiple tools.
- Evidence: .dogfood/concord/testing-log.md
- Requested outcome: Consistent and/or parsing support with regression coverage.

## Draft 2: Align push semantics between VM and interpreter
- Repo: kujo
- Priority: P0
- Problem: push(array, value) requires reassignment and can differ by runtime expectations.
- Evidence: .dogfood/concord/testing-log.md
- Requested outcome: One behavior contract with explicit diagnostics/tests.

## Draft 3: Export non-function symbols across modules
- Repo: kujo
- Priority: P1
- Problem: Constants/variables cannot be imported directly, causing duplication.
- Evidence: .dogfood/concord/testing-log.md
- Requested outcome: Export/import support for const/let symbols.

## Draft 4: Improve spec validate scope ergonomics
- Repo: kujo-spec
- Priority: P3
- Problem: validate requires working directory inside target project.
- Evidence: .dogfood/concord/testing-log.md
- Requested outcome: allow read-only validate/render for explicit absolute paths.
EOF
}

run_cycle() {
	local cycle_index="$1"
	local ts run_dir scan_dir tasks_dir checks_dir records_file
	local test_log gate_summary_file cycle_issue_drafts_file
	local concord_test_status
	ts="$(date -u +"%Y%m%dT%H%M%SZ")"
	run_dir="$(mktemp -d "$RUNS_DIR/${ts}-${cycle_index}.XXXXXX")"
	scan_dir="$run_dir/scans"
	tasks_dir="$run_dir/tasks"
	checks_dir="$run_dir/checks"
	records_file="$run_dir/records.jsonl"
	test_log="$run_dir/concord-test.log"
	gate_summary_file="$run_dir/gate-summary.json"
	cycle_issue_drafts_file="$run_dir/upstream-issue-drafts.md"

	mkdir -p "$scan_dir" "$tasks_dir" "$checks_dir"
	: > "$records_file"

	echo "[loop:$cycle_index] running concord tests"
	if (cd "$REPO_ROOT" && "$KUJO_CMD" test > "$test_log" 2>&1); then
		concord_test_status="pass"
	else
		concord_test_status="fail"
	fi

	local repo_index=0
	while IFS= read -r repo_path; do
		if [[ -z "$repo_path" || "$repo_path" =~ ^# ]]; then
			continue
		fi

		repo_index=$((repo_index + 1))
		local repo_slug safe_repo_slug artifact_slug scan_json scan_md tasks_md
		repo_slug="$(basename "$repo_path")"
		safe_repo_slug="$(printf '%s' "$repo_slug" | tr -c '[:alnum:]_.-' '_')"
		artifact_slug="$(printf '%03d' "$repo_index")-$safe_repo_slug"
		scan_json="$scan_dir/$artifact_slug.scan.json"
		scan_md="$scan_dir/$artifact_slug.scan.md"
		tasks_md="$tasks_dir/$artifact_slug.tasks.md"

		if [[ ! -d "$repo_path" ]]; then
			append_record "$records_file" "$ts" "$repo_slug" "$repo_path" "missing" 0 "critical" 1 0 0 0
			continue
		fi

		local scan_status=0
		(cd "$REPO_ROOT" && "$KUJO_CMD" run concord.kujo -- scan --dir "$repo_path" --format json --output "$scan_json" >/dev/null 2>&1) || scan_status=$?
		if [[ "$scan_status" -ne 0 && "$scan_status" -ne 1 ]]; then
			append_record "$records_file" "$ts" "$repo_slug" "$repo_path" "scan_failed" 0 "critical" 1 0 0 0
			continue
		fi

		local artifact_status="ok"
		scan_status=0
		(cd "$REPO_ROOT" && "$KUJO_CMD" run concord.kujo -- scan --dir "$repo_path" --format markdown --output "$scan_md" >/dev/null 2>&1) || scan_status=$?
		if [[ "$scan_status" -ne 0 && "$scan_status" -ne 1 ]]; then
			artifact_status="artifact_failed"
		fi
		if ! (cd "$REPO_ROOT" && "$KUJO_CMD" run concord.kujo -- tasks --dir "$repo_path" --output "$tasks_md" >/dev/null 2>&1); then
			artifact_status="artifact_failed"
		fi

		for cat in cli-docs manifest examples; do
			(cd "$REPO_ROOT" && "$KUJO_CMD" run concord.kujo -- check "$cat" --dir "$repo_path" --format json > "$checks_dir/$artifact_slug.$cat.json" 2>/dev/null) || true
		done

		local total highest critical high medium low
		total="$(jq -r '.summary.total_findings // 0' "$scan_json")"
		highest="$(jq -r '.summary.highest_severity // "none"' "$scan_json")"
		critical="$(jq '[.findings[]? | select(.severity == "critical")] | length' "$scan_json")"
		high="$(jq '[.findings[]? | select(.severity == "high")] | length' "$scan_json")"
		medium="$(jq '[.findings[]? | select(.severity == "medium")] | length' "$scan_json")"
		low="$(jq '[.findings[]? | select(.severity == "low")] | length' "$scan_json")"

		append_record "$records_file" "$ts" "$repo_slug" "$repo_path" "$artifact_status" "$total" "$highest" "$critical" "$high" "$medium" "$low"
	done < "$REPOS_FILE"

	cat "$records_file" >> "$TREND_FILE"
	if [[ "$TREND_MAX_RECORDS" -gt 0 ]]; then
		local trend_tmp
		trend_tmp="$(mktemp "$TREND_DIR/scan-trend.XXXXXX")"
		tail -n "$TREND_MAX_RECORDS" "$TREND_FILE" > "$trend_tmp"
		mv "$trend_tmp" "$TREND_FILE"
	fi

	jq -s \
		--arg timestamp "$ts" \
		--arg concord_test "$concord_test_status" \
		'{
			timestamp: $timestamp,
			concord_test: $concord_test,
			repos: .,
			totals: {
				repositories: length,
				total_findings: (map(.total_findings) | add // 0),
				critical: (map(.critical) | add // 0),
				high: (map(.high) | add // 0),
				medium: (map(.medium) | add // 0),
				low: (map(.low) | add // 0)
			},
		gate_failed: ( ($concord_test != "pass") or any(.[]; .status != "ok" or .highest_severity == "critical" or .highest_severity == "high") )
		}' "$records_file" > "$gate_summary_file"

	{
		echo "# Concord Continuous Loop Summary"
		echo
		echo "Cycle timestamp: $ts"
		echo "Concord tests: $concord_test_status"
		echo
		echo "| Repo | Status | Findings | Highest | Critical | High | Medium | Low |"
		echo "|------|--------|----------|---------|----------|------|--------|-----|"
		while IFS= read -r row; do
			repo="$(echo "$row" | jq -r '.repo')"
			status="$(echo "$row" | jq -r '.status')"
			total="$(echo "$row" | jq -r '.total_findings')"
			highest="$(echo "$row" | jq -r '.highest_severity')"
			critical="$(echo "$row" | jq -r '.critical')"
			high="$(echo "$row" | jq -r '.high')"
			medium="$(echo "$row" | jq -r '.medium')"
			low="$(echo "$row" | jq -r '.low')"
			echo "| $(markdown_cell "$repo") | $(markdown_cell "$status") | $total | $(markdown_cell "$highest") | $critical | $high | $medium | $low |"
		done < "$records_file"
	} > "$LATEST_SUMMARY_FILE"

	build_issue_drafts "$ISSUE_DRAFTS_FILE"
	cp "$ISSUE_DRAFTS_FILE" "$cycle_issue_drafts_file"

	echo "[loop:$cycle_index] cycle complete: $run_dir"
	CYCLE_GATE_FAILED="$(jq -r '.gate_failed' "$gate_summary_file")"
}

cycle=0
overall_gate_failed=0

while true; do
	cycle=$((cycle + 1))
	run_cycle "$cycle"
	if [[ "$CYCLE_GATE_FAILED" == "true" ]]; then
		overall_gate_failed=1
	fi

	if [[ "$ITERATIONS" -gt 0 && "$cycle" -ge "$ITERATIONS" ]]; then
		break
	fi

	echo "[loop:$cycle] sleeping for ${SLEEP_SECONDS}s"
	sleep "$SLEEP_SECONDS"
done

if [[ "$STRICT_GATE" -eq 1 && "$overall_gate_failed" -eq 1 ]]; then
	echo "Continuous loop finished with gate failures" >&2
	exit 1
fi

echo "Continuous loop finished successfully"
