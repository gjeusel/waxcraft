import assert from 'node:assert/strict';
import { PassThrough } from 'node:stream';
import { test } from 'node:test';
import { observeFocusInput } from './focus-input.ts';

test('observes focus even when Pi handles stdin first, without consuming input', () => {
  const input = new PassThrough();
  const received: string[] = [];
  input.on('data', (data) => received.push(data.toString()));
  const focused: boolean[] = [];
  const stop = observeFocusInput(input, (value) => focused.push(value));
  try {
    input.write('\x1b[O');
    input.write('\x1b[I');
    assert.deepEqual(focused, [false, true]);
    assert.deepEqual(received, ['\x1b[O', '\x1b[I']);
  } finally {
    stop();
    input.destroy();
  }
});

test('parses split focus reports and ignores focus-like bracketed paste', () => {
  const input = new PassThrough();
  const focused: boolean[] = [];
  const stop = observeFocusInput(input, (value) => focused.push(value));
  try {
    input.write('\x1b[');
    input.write('O');
    input.write('\x1b[200~pasted\x1b[I\x1b[201~');
    input.write('ordinary input');
    input.write('\x1b[I');
    assert.deepEqual(focused, [false, true]);
  } finally {
    stop();
    input.destroy();
  }
});

test('cleanup removes the listener and discards partial input', () => {
  const input = new PassThrough();
  const focused: boolean[] = [];
  const stop = observeFocusInput(input, (value) => focused.push(value));
  input.write('\x1b[');
  stop();
  stop();
  assert.equal(input.listenerCount('data'), 0);
  input.write('O\x1b[I');
  assert.deepEqual(focused, []);
  input.destroy();
});
