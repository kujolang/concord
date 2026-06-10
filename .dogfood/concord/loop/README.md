# Concord Continuous Loop Artifacts

This directory stores outputs from the continuous concord loop runner.

## Structure

- `repos.txt`: Target repository matrix.
- `runs/<timestamp>/`: Per-cycle raw outputs.
- `trend/scan-trend.jsonl`: Append-only summary rows (one per repo per cycle).
- `trend/latest-summary.md`: Latest cycle summary.
- `upstream-issue-drafts.md`: Current upstream issue draft backlog.

## Notes

- Timestamps are UTC (`YYYYMMDDTHHMMSSZ`).
- The loop writes both Markdown and JSON scan artifacts.
- The gate summary for each cycle is stored in `runs/<timestamp>/gate-summary.json`.
