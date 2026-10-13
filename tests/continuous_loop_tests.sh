#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
cleanup() {
	rm -rf "$test_root"
}
trap cleanup EXIT

fake_kujo="$test_root/fake-kujo"
cat > "$fake_kujo" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail

command_name="${4:-}"
output_path=""
format="markdown"
index=1
while [[ "$index" -le "$#" ]]; do
	value="${!index}"
	if [[ "$value" == "--output" ]]; then
		index=$((index + 1))
		output_path="${!index}"
	elif [[ "$value" == "--format" ]]; then
		index=$((index + 1))
		format="${!index}"
	fi
	index=$((index + 1))
done

if [[ "$command_name" == "scan" ]]; then
	if [[ "$format" == "json" ]]; then
		content='{"summary":{"total_findings":1,"highest_severity":"high"},"findings":[{"severity":"high"}]}'
	else
		content='# Concord Drift Report'
	fi
	printf '%s\n' "$content" > "$output_path"
	exit 1
fi

if [[ "$command_name" == "tasks" ]]; then
	printf '# Concord Fix Tasks\n' > "$output_path"
	exit 0
fi

if [[ "$command_name" == "check" ]]; then
	printf '[]\n'
	exit 3
fi

exit 2
FAKE
chmod +x "$fake_kujo"

mkdir -p "$test_root/bin"
cat > "$test_root/bin/node" <<'FAKE_NODE'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == "scripts/verify-native.mjs" ]]
[[ "${KUJO_RUNTIME_BIN:-}" == "${EXPECTED_NATIVE_BIN:-}" ]]
exit "${FAKE_NATIVE_STATUS:-0}"
FAKE_NODE
chmod +x "$test_root/bin/node"
export PATH="$test_root/bin:$PATH"
export EXPECTED_NATIVE_BIN="$fake_kujo"
export KUJO_RUNTIME_BIN="/unused-default-runtime"

fixture_dir="$test_root/repo \"quoted\"|name"
mkdir -p "$fixture_dir"
repos_file="$test_root/repos.txt"
printf '%s\n' "$fixture_dir" > "$repos_file"
loop_root="$test_root/loop"

CONCORD_LOOP_ROOT="$loop_root" KUJO_BIN="$fake_kujo" \
	"$repo_root/scripts/concord_continuous_loop.sh" \
	--repos-file "$repos_file" \
	--iterations 2 \
	--sleep-seconds 0 \
	--trend-max-records 1 \
	--strict-gate >/dev/null 2>&1 && {
	echo "expected strict gate to fail for a high finding" >&2
	exit 1
}

latest_run="$(find "$loop_root/runs" -mindepth 1 -maxdepth 1 -type d | sort | tail -1)"
jq -e '.concord_test == "pass" and .repos[0].status == "ok" and .repos[0].total_findings == 1 and .repos[0].high == 1 and .gate_failed == true' \
	"$latest_run/gate-summary.json" >/dev/null
jq -e '.status == "ok" and (.path | contains("quoted"))' "$latest_run/records.jsonl" >/dev/null
[[ "$(wc -l < "$loop_root/trend/scan-trend.jsonl" | tr -d ' ')" == "1" ]]
grep -F 'repo "quoted"\|name' "$loop_root/trend/latest-summary.md" >/dev/null
[[ "$(find "$latest_run/scans" -type f -name '001-*.scan.json' | wc -l | tr -d ' ')" == "1" ]]

FAKE_NATIVE_STATUS=1 CONCORD_LOOP_ROOT="$test_root/native-failure" KUJO_BIN="$fake_kujo" \
	"$repo_root/scripts/concord_continuous_loop.sh" --repos-file "$repos_file" --iterations 1 >/dev/null 2>&1
native_failure_run="$(find "$test_root/native-failure/runs" -mindepth 1 -maxdepth 1 -type d | head -1)"
jq -e '.concord_test == "fail" and .gate_failed == true' "$native_failure_run/gate-summary.json" >/dev/null

set +e
CONCORD_LOOP_ROOT="$test_root/missing-value" KUJO_BIN="$fake_kujo" \
	"$repo_root/scripts/concord_continuous_loop.sh" --iterations >/dev/null 2>&1
missing_value_status=$?
CONCORD_LOOP_ROOT="$test_root/negative-value" KUJO_BIN="$fake_kujo" \
	"$repo_root/scripts/concord_continuous_loop.sh" --repos-file "$repos_file" --iterations -1 >/dev/null 2>&1
negative_value_status=$?
set -e

[[ "$missing_value_status" == "2" ]]
[[ "$negative_value_status" == "2" ]]

echo "continuous loop tests passed"
