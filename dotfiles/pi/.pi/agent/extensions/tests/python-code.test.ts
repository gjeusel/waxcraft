import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { Monty } from '@pydantic/monty';
import { PythonCodeExecutionError, runPythonCode } from '../python-code.ts';

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
