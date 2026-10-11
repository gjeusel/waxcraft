import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test, { after } from 'node:test';
import { runInNewContext } from 'node:vm';
import { SessionManager } from '../extensions/node_modules/@earendil-works/pi-coding-agent/dist/index.js';
import { AutoModeState, forwardApproval, registerSafetySession, withWorkerParent } from '../extensions/pi-safety/session-state.ts';

const require = createRequire(new URL('../extensions/package.json', import.meta.url));
const ts = require('typescript');
const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), '.pi/agent');
const source = readFileSync(join(agentDir, 'npm/node_modules/@tintinweb/pi-subagents/src/agent-runner.ts'), 'utf8');
const patchPath = fileURLToPath(new URL('./pi-subagents-0.19.0-safety-parent.patch', import.meta.url));
const scratch = mkdtempSync(join(tmpdir(), 'pi-safety-parent-patch-'));
after(() => rmSync(scratch, { recursive: true, force: true }));
mkdirSync(join(scratch, 'src'));
const runnerPath = join(scratch, 'src/agent-runner.ts');
writeFileSync(runnerPath, source);

function apply(...args) {
  return spawnSync('git', ['apply', ...args, patchPath], { cwd: scratch, encoding: 'utf8' });
}

// Accept either installation state, but normalize and exercise the patch only on the scratch copy.
if (apply('--reverse', '--check').status === 0) assert.equal(apply('--reverse').status, 0);
const original = readFileSync(runnerPath, 'utf8');
const applied = apply();
assert.equal(applied.status, 0, applied.stderr);
const patched = readFileSync(runnerPath, 'utf8');
const start = patched.indexOf('  // Bind extensions so that session_start fires');
const end = patched.indexOf('  // With `allowedToolNames` unset', start);
assert.ok(start >= 0 && end > start, 'upstream extension binding boundary changed');
const { outputText } = ts.transpileModule(`exports.bind = async (session, ctx, options) => {\n${patched.slice(start, end)}\n};`, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
});
const key = Symbol.for('waxcraft:pi-safety:bind-worker:v1');

function binding(withBridge) {
  const sandbox = { exports: {}, ...(withBridge ? { [key]: withWorkerParent } : {}) };
  runInNewContext(outputText, sandbox, { filename: runnerPath });

  return sandbox.exports.bind;
}

function context(hasUI) {
  return { cwd: '/project', hasUI, sessionManager: SessionManager.inMemory('/project') };
}

test('runner patch applies, detects its applied state, and reverses cleanly', () => {
  assert.notEqual(apply('--check').status, 0);
  assert.equal(apply('--reverse', '--check').status, 0);
  assert.equal(apply('--reverse').status, 0);
  assert.equal(readFileSync(runnerPath, 'utf8'), original);
  assert.equal(apply('--check').status, 0);
  assert.equal(apply().status, 0);
  assert.equal(readFileSync(runnerPath, 'utf8'), patched);
});

test('installer applies the runner patch once, detects it afterward, and reports Git errors', () => {
  const root = join(scratch, 'installer');
  const packagePath = 'npm/node_modules/@tintinweb/pi-subagents';
  const packageDir = join(root, packagePath);
  mkdirSync(join(packageDir, 'src'), { recursive: true });
  const installedRunner = join(packageDir, 'src/agent-runner.ts');
  writeFileSync(installedRunner, original);
  writeFileSync(join(packageDir, 'src/agent-color.ts'),
    readFileSync(join(agentDir, packagePath, 'src/agent-color.ts'), 'utf8'));
  const install = () => spawnSync('sh', [fileURLToPath(new URL('./apply.sh', import.meta.url))], {
    env: { ...process.env, PI_CODING_AGENT_DIR: root }, encoding: 'utf8',
  });

  const first = install();
  assert.equal(first.status, 0, first.stderr);
  assert.match(first.stdout, /Applied pi-subagents-0\.19\.0-safety-parent\.patch/);
  assert.equal(readFileSync(installedRunner, 'utf8'), patched);

  const second = install();
  assert.equal(second.status, 0, second.stderr);
  assert.match(second.stdout, /Already applied pi-subagents-0\.19\.0-safety-parent\.patch/);
  assert.equal(readFileSync(installedRunner, 'utf8'), patched);

  const incompatible = patched.replace('const bindExtensions = () => session.bindExtensions({', 'upstream binding changed');
  writeFileSync(installedRunner, incompatible);
  const failed = install();
  assert.notEqual(failed.status, 0);
  assert.match(failed.stderr, /Cannot patch src\/agent-runner\.ts/);
  assert.match(failed.stderr, /error: patch failed: src\/agent-runner\.ts/);
  assert.equal(readFileSync(installedRunner, 'utf8'), incompatible);
});

test('patched native binding supplies the real parent before in-memory session_start', async (t) => {
  const lifetime = new AbortController();
  t.after(() => lifetime.abort());
  const parent = context(true);
  const child = context(false);
  const mode = new AutoModeState(false);
  registerSafetySession(parent, async () => true, mode, lifetime.signal);
  let childState;
  let calls = 0;
  const activity = [];
  await binding(true)({
    async bindExtensions(options) {
      calls++;
      await Promise.resolve();
      childState = registerSafetySession(child, async () => false, new AutoModeState(true), lifetime.signal);
      options.onError({ extensionPath: '/test/extension.ts' });
    },
  }, parent, { onToolActivity: (event) => activity.push(event) });

  assert.equal(calls, 1);
  assert.equal(childState.mode, mode);
  mode.setEnabled(true);
  assert.equal(childState.mode.snapshot().enabled, true);
  assert.equal(await forwardApproval({ title: 'bash', content: 'echo harmless' }, child, lifetime.signal), true);
  assert.equal(child.sessionManager.getSessionFile(), undefined);
  assert.equal(activity[0].toolName, 'extension-error:/test/extension.ts');
});

test('without pi-safety the patched runner still binds once and awaits completion', async () => {
  let complete = false;
  await binding(false)({ async bindExtensions() {
    await Promise.resolve();
    assert.equal(complete, false);
    complete = true;
  } }, context(false), {});
  assert.equal(complete, true);
});

test('failed binding propagates its error without leaking parent scope', async (t) => {
  const lifetime = new AbortController();
  t.after(() => lifetime.abort());
  const parent = context(true);
  const state = new AutoModeState(false);
  registerSafetySession(parent, async () => true, state, lifetime.signal);
  const error = new Error('bind failed');
  await assert.rejects(binding(true)({ async bindExtensions() { throw error; } }, parent, {}), error);
  const unrelated = context(false);
  const localState = new AutoModeState(true);
  const registered = registerSafetySession(unrelated, async () => false, localState, lifetime.signal);
  assert.equal(registered.mode, localState);
  assert.equal(await forwardApproval({ title: 'bash', content: 'echo unrelated' }, unrelated, lifetime.signal), undefined);
});
