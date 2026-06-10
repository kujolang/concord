#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOOP_ROOT="$REPO_ROOT/.dogfood/concord/loop"
RUNS_DIR="$LOOP_ROOT/runs"
TREND_DIR="$LOOP_ROOT/trend"
TREND_FILE="$TREND_DIR/scan-trend.jsonl"
LATEST_SUMMARY_FILE="$TREND_DIR/latest-summary.md"
ISSUE_DRAFTS_FILE="$LOOP_ROOT/upstream-issue-drafts.md"

REPOS_FILE="$LOOP_ROOT/repos.txt"
ITERATIONS=1
SLEEP_SECONDS=300
STRICT_GATE=0
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
  --kujo-bin PATH        Kujo runtime binary override
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--repos-file)
			REPOS_FILE="$2"
			shift 2
			;;
		--iterations)
			ITERATIONS="$2"
			shift 2
			;;
		--sleep-seconds)
			SLEEP_SECONDS="$2"
			shift 2
			;;
		--strict-gate)
			STRICT_GATE=1
			shift
			;;
		--kujo-bin)
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

if [[ ! -f "$REPOS_FILE" ]]; then
	echo "Repos file not found: $REPOS_FILE" >&2
	exit 2
fi

mkdir -p "$RUNS_DIR" "$TREND_DIR"
touch "$TREND_FILE"

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
	run_dir="$RUNS_DIR/$ts"
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

	while IFS= read -r repo_path; do
		if [[ -z "$repo_path" || "$repo_path" =~ ^# ]]; then
			continue
		fi

		local repo_slug scan_json scan_md tasks_md
		repo_slug="$(basename "$repo_path")"
		scan_json="$scan_dir/$repo_slug.scan.json"
		scan_md="$scan_dir/$repo_slug.scan.md"
		tasks_md="$tasks_dir/$repo_slug.tasks.md"

		if [[ ! -d "$repo_path" ]]; then
			printf '{"timestamp":"%s","repo":"%s","path":"%s","status":"missing","total_findings":0,"highest_severity":"critical","critical":1,"high":0,"medium":0,"low":0}\n' "$ts" "$repo_slug" "$repo_path" >> "$records_file"
			continue
		fi

		if ! (cd "$REPO_ROOT" && "$KUJO_CMD" run concord.kujo -- scan --dir "$repo_path" --format json --output "$scan_json" >/dev/null 2>&1); then
			printf '{"timestamp":"%s","repo":"%s","path":"%s","status":"scan_failed","total_findings":0,"highest_severity":"critical","critical":1,"high":0,"medium":0,"low":0}\n' "$ts" "$repo_slug" "$repo_path" >> "$records_file"
			continue
		fi

		(cd "$REPO_ROOT" && "$KUJO_CMD" run concord.kujo -- scan --dir "$repo_path" --format markdown --output "$scan_md" >/dev/null 2>&1)
		(cd "$REPO_ROOT" && "$KUJO_CMD" run concord.kujo -- tasks --dir "$repo_path" --output "$tasks_md" >/dev/null 2>&1)

		for cat in cli-docs manifest examples; do
			(cd "$REPO_ROOT" && "$KUJO_CMD" run concord.kujo -- check "$cat" --dir "$repo_path" --format json > "$checks_dir/$repo_slug.$cat.json" 2>/dev/null) || true
		done

		local total highest critical high medium low
		total="$(jq -r '.summary.total_findings // 0' "$scan_json")"
		highest="$(jq -r '.summary.highest_severity // "none"' "$scan_json")"
		critical="$(jq '[.findings[]? | select(.severity == "critical")] | length' "$scan_json")"
		high="$(jq '[.findings[]? | select(.severity == "high")] | length' "$scan_json")"
		medium="$(jq '[.findings[]? | select(.severity == "medium")] | length' "$scan_json")"
		low="$(jq '[.findings[]? | select(.severity == "low")] | length' "$scan_json")"

		printf '{"timestamp":"%s","repo":"%s","path":"%s","status":"ok","total_findings":%s,"highest_severity":"%s","critical":%s,"high":%s,"medium":%s,"low":%s}\n' \
			"$ts" "$repo_slug" "$repo_path" "$total" "$highest" "$critical" "$high" "$medium" "$low" >> "$records_file"
	done < "$REPOS_FILE"

	cat "$records_file" >> "$TREND_FILE"

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
			gate_failed: ( ($concord_test != "pass") or any(.[]; .highest_severity == "critical" or .highest_severity == "high") )
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
			echo "| $repo | $status | $total | $highest | $critical | $high | $medium | $low |"
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
