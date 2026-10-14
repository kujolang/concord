import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { access, cp, mkdir, mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, isAbsolute, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const source = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const runtime = process.env.KUJO_RUNTIME_BIN;
if (!runtime || !isAbsolute(runtime)) throw new Error('Set KUJO_RUNTIME_BIN to an absolute compatible Kujo executable.');
const modes = [[], ['--interpreter']];
for (const flags of modes) {
  const directory = await mkdtemp(join(tmpdir(), 'concord-native-tests-'));
  try {
    for (const path of ['README.md', 'kennel.toml', 'kujo.toml', 'concord.spec.yml', 'concord.kujo', 'src', 'tests', 'examples', 'docs']) {
      await cp(join(source, path), join(directory, path), { recursive: true });
    }
    // The fixed test driver is placed next to src for isolated module imports.
    await cp(join(source, 'tests/concord_tests.kujo'), join(directory, 'native-tests.kujo'));
    const result = spawnSync(runtime, ['run', '--isolated-imports', ...flags, 'native-tests.kujo'], { cwd: directory, encoding: 'utf8', timeout: 60000, maxBuffer: 2_000_000 });
    process.stdout.write(result.stdout ?? '');
    process.stderr.write(result.stderr ?? '');
    assert.ifError(result.error);
    assert.equal(result.status, 0, `${flags.length ? 'interpreter' : 'VM'} assertions failed`);
    const summary = JSON.parse(result.stdout.trim().split('\n').at(-1));
    assert.equal(summary.passed, 106, 'Every registered assertion must execute');
    assert.equal(summary.failed, 0);
    const driver = (await readFile(join(directory, 'native-tests.kujo'), 'utf8')).replace(/\r\n/g, '\n');
    const negativeDriver = driver.replace('\ntest_common()\n', '\ncheck(false, "runner negative control")\ntest_common()\n');
    assert.notEqual(negativeDriver, driver, 'Negative-control assertion must be injected');
    await writeFile(join(directory, 'negative-control.kujo'), negativeDriver);
    // Fresh fixture names let the negative control exercise the full suite again.
    for (const path of ['.concord-recursive-fixture', '.concord-worktree-fixture', '.concord-cli-docs-fixture', '.concord-nested-docs-fixture', '.concord-oversized-fixture', '.concord-examples-fixture', '.concord-metadata-fixture', '.concord-snapshot-fixture']) await rm(join(directory, path), { recursive: true, force: true });
    const negative = spawnSync(runtime, ['run', '--isolated-imports', ...flags, 'negative-control.kujo'], { cwd: directory, encoding: 'utf8', timeout: 60000, maxBuffer: 2_000_000 });
    assert.ifError(negative.error);
    assert.equal(negative.status, 1, 'A failed assertion must produce a failing process');
    assert.equal(JSON.parse(negative.stdout.trim().split('\n').at(-1)).failed, 1);

    const fixture = join(directory, 'cli-fixture'); await mkdir(fixture);
    await writeFile(join(fixture, 'kennel.toml'), '[package]\nname="fixture"\nversion="1.0.0"\n[kujo]\nentry="tool.kujo"\n');
    await writeFile(join(fixture, 'tool.kujo'), 'write_file("project-executed.txt", "unexpected execution")\nsubcommand := "scan"\nif subcommand == "scan" { print("ok") }\n');
    await writeFile(join(fixture, 'README.md'), '# fixture\n![Version](https://img.shields.io/badge/version-9.0.0-black)\n```sh\nkujo run tool.kujo scan\n```\n');
    function invoke(args, status) {
      const result = spawnSync(runtime, ['run', '--isolated-imports', ...flags, 'concord.kujo', '--', ...args, ...(args[0] === 'version' ? [] : ['--dir', fixture])], { cwd: directory, encoding: 'utf8', timeout: 60000, maxBuffer: 2_000_000 });
      assert.ifError(result.error);
      assert.equal(result.status, status, `${args.join(' ')}: ${result.stderr} ${result.stdout}`);
      return result.stdout;
    }
    const packageVersion = (await readFile(join(directory, 'kennel.toml'), 'utf8')).match(/^version = "([^"]+)"/m)[1];
    assert.ok(invoke(['version'], 0).startsWith(`Concord v${packageVersion}\n`), 'CLI version must match the installed package');
    const scan = JSON.parse(invoke(['scan', '--format', 'json'], 1));
    assert.equal(scan.summary.highest_severity, 'high');
    assert.ok(scan.findings.some(item => item.id === 'version-inconsistency'));
    assert.ok(JSON.parse(invoke(['check', 'versions', '--format', 'json'], 3)).some(item => item.id === 'version-inconsistency'));
    assert.equal(JSON.parse(invoke(['report', '--format', 'json'], 0)).summary.highest_severity, 'high');
    assert.match(invoke(['scan'], 1), /# Concord Drift Report/);
    assert.match(invoke(['tasks'], 0), /# Concord Fix Tasks/);
    await assert.rejects(access(join(directory, 'project-executed.txt')));
    await assert.rejects(access(join(fixture, 'project-executed.txt')));
    console.log(`${flags.length ? 'Interpreter' : 'VM'}: ${summary.passed} assertions, negative control and five CLI checks passed`);
  } finally { await rm(directory, { recursive: true, force: true }); }
}
