import assert from 'node:assert/strict';
import test from 'node:test';
import { evaluate, globToRegex, parseRules } from './rules.ts';

test('wildcards match across newlines', () => {
  const pattern = globToRegex('kubectl exec*');
  const command = "kubectl exec -n etl pod -- python - <<'PY'\nprint('ok')\nPY";

  assert.match(command, pattern);
});

test('multiline bash commands are blocked by matching deny rules', () => {
  const denyRules = parseRules(['Bash(kubectl exec*)']);
  const command = "kubectl exec -n etl pod -- python - <<'PY'\nprint('ok')\nPY";

  const result = evaluate('bash', { command }, [], denyRules);

  assert.equal(result.blocked, true);
  assert.match(result.reason ?? '', /Bash\(kubectl exec\*\)/);
});

test('glob metacharacters other than wildcards remain literal', () => {
  const pattern = globToRegex('echo [ok] $HOME *.json');

  assert.match('echo [ok] $HOME config.json', pattern);
  assert.doesNotMatch('echo o $HOME config.json', pattern);
});

test('nonmatching bash commands remain allowed', () => {
  const denyRules = parseRules(['Bash(kubectl exec*)']);

  assert.deepEqual(evaluate('bash', { command: 'kubectl get pods' }, [], denyRules), { blocked: false });
});
