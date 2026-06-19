# Concord Examples

Run Concord against this repository:

```bash
./kujo run concord.kujo -- scan
```

Generate a JSON report for automation:

```bash
./kujo run concord.kujo -- scan --format json --output /path/to/scan.json
```

Scan another local project:

```bash
./kujo run concord.kujo -- scan --dir /path/to/other-project
```
