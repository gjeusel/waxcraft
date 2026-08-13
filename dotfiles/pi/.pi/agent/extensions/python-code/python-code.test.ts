import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { Monty } from '@pydantic/monty';
import { initializePythonCodeExtension, PythonCodeExecutionError, runPythonCode } from './index.ts';

let pool: Monty;

before(async () => {
  pool = await Monty.create({
    maxProcesses: 1,
    requestTimeout: 2,
    durationLimitGrace: 0.1,
  });
});

after(async () => {
  await pool.close();
});

test('warns instead of failing when a runtime dependency is missing', async () => {
  type SessionStartHandler = (
    event: unknown,
    ctx: { hasUI: boolean; ui: { notify(message: string, level: string): void } },
  ) => void;

  let sessionStartHandler: SessionStartHandler | undefined;
  let registeredTool = false;
  let warning: { message: string; level: string } | undefined;
  const pi = {
    on(event: string, handler: SessionStartHandler) {
      if (event === 'session_start') sessionStartHandler = handler;
    },
    registerTool() {
      registeredTool = true;
    },
  } as unknown as ExtensionAPI;

  await initializePythonCodeExtension(pi, (specifier) => {
    throw Object.assign(new Error(`Cannot find module '${specifier}'`), { code: 'MODULE_NOT_FOUND' });
  });

  assert.equal(registeredTool, false);
  assert.ok(sessionStartHandler);
  sessionStartHandler(
    {},
    {
      hasUI: true,
      ui: {
        notify(message, level) {
          warning = { message, level };
        },
      },
    },
  );
  assert.ok(warning);
  assert.equal(warning.level, 'warning');
  assert.match(warning.message, /Python Code Tool disabled: required package "@pydantic\/monty" is not installed/);
  assert.match(warning.message, /Run "npm install" in .*extensions\/python-code\.$/);
});

test('returns printed output and the final expression value', async () => {
  const result = await runPythonCode(pool, 'print("hello")\n6 * 7');

  assert.equal(result.text, 'hello\n=> 42');
  assert.equal(result.truncated, false);
});

test('uses a fresh interpreter for each call', async () => {
  assert.equal((await runPythonCode(pool, 'answer = 42')).text, '(no output)');

  await assert.rejects(runPythonCode(pool, 'answer'), (error: unknown) => {
    assert.ok(error instanceof PythonCodeExecutionError);
    assert.match(error.message, /NameError/);
    return true;
  });
});

test('returns a traceback without a fallback hint for ordinary Python errors', async () => {
  await assert.rejects(runPythonCode(pool, '1 / 0'), (error: unknown) => {
    assert.ok(error instanceof PythonCodeExecutionError);
    assert.match(error.message, /Traceback \(most recent call last\):/);
    assert.match(error.message, /ZeroDivisionError/);
    assert.doesNotMatch(error.message, /Monty sandbox limitation/);
    return true;
  });
});

test('suggests normal Python for likely Monty limitations', async () => {
  await assert.rejects(runPythonCode(pool, 'import definitely_missing_package'), (error: unknown) => {
    assert.ok(error instanceof PythonCodeExecutionError);
    assert.match(error.message, /ModuleNotFoundError/);
    assert.match(error.message, /Monty sandbox limitation/);
    assert.match(error.message, /normal Python via the bash tool/);
    return true;
  });
});

test('caps and marks large output', async () => {
  const result = await runPythonCode(pool, 'print("x" * 200)', { maxBytes: 64, maxLines: 20 });

  assert.equal(result.truncated, true);
  assert.match(result.text, /^x+/);
  assert.match(result.text, /\[output truncated\]$/);
});

test('enforces the execution timeout', async () => {
  await assert.rejects(
    runPythonCode(pool, 'while True:\n    pass', {
      limits: { maxDurationSecs: 0.02, maxMemory: 64 * 1024 * 1024 },
    }),
    (error: unknown) => {
      assert.ok(error instanceof PythonCodeExecutionError);
      assert.match(error.message, /Timeout|time limit|duration/i);
      return true;
    },
  );
});
