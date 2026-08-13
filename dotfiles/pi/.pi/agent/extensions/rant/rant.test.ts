import assert from 'node:assert/strict';
import test from 'node:test';
import { formatRantEntry, formatTimestamp } from './index.ts';

test('formats a timestamp as YY-MM-DD HH:MM', () => {
  assert.equal(formatTimestamp(new Date(2026, 7, 5, 9, 3)), '26-08-05 09:03');
});

test('formats an entry with cwd and trailing newline', () => {
  assert.equal(
    formatRantEntry('jq filter kept failing', '/Users/gjeusel/src/waxcraft', new Date(2026, 7, 5, 9, 3)),
    '## 26-08-05 09:03\n\ncwd: /Users/gjeusel/src/waxcraft\n\njq filter kept failing\n',
  );
});

test('includes the trigger label in the heading when given', () => {
  const entry = formatRantEntry('thought', '/tmp', new Date(2026, 7, 5, 9, 3), 'jq');
  assert.ok(entry.startsWith('## 26-08-05 09:03 — jq\n'));
});
