import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { runInNewContext } from 'node:vm';

const require = createRequire(new URL('../extensions/package.json', import.meta.url));
const ts = require('typescript');
const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), '.pi/agent');
const sourcePath = join(agentDir, 'npm/node_modules/@tintinweb/pi-subagents/src/agent-color.ts');
const source = readFileSync(sourcePath, 'utf8');
const { outputText } = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
});
const exports = {};
// Exercise the installed renderer without loading the extension's agent registry.
runInNewContext(outputText, {
  exports,
  require(id) {
    assert.equal(id, './agent-types.js');
    return { getConfig() { throw new Error('Label rendering should not access the agent registry'); } };
  },
}, { filename: sourcePath });
const { renderAgentNameLabel } = exports;
const theme = {
  fg: (color, text) => `<${color}>${text}</${color}>`,
  bold: text => `\x1b[1m${text}\x1b[22m`,
};

test('cyan is foreground-only, without badge padding', () => {
  assert.equal(
    renderAgentNameLabel('Code Search', 'cyan', theme),
    '\x1b[38;2;8;145;178mCode Search\x1b[39m',
  );
});

test('hex colors retain their RGB values', () => {
  assert.equal(
    renderAgentNameLabel('Agent', '#12abef', theme),
    '\x1b[38;2;18;171;239mAgent\x1b[39m',
  );
});

test('256-color terminals use a foreground palette entry', () => {
  assert.equal(
    renderAgentNameLabel('Code Search', 'cyan', { ...theme, getColorMode: () => '256color' }),
    '\x1b[38;5;31mCode Search\x1b[39m',
  );
});

test('bold labels never set or reset the enclosing background', () => {
  const label = renderAgentNameLabel('Code Search', 'cyan', theme, {
    bold: true,
    restoreBackground: '\x1b[48;2;10;20;30m',
  });
  assert.equal(label, '\x1b[38;2;8;145;178m\x1b[1mCode Search\x1b[22m\x1b[39m');
  assert.doesNotMatch(label, /\x1b\[(?:0|4[0-9]|10[0-7])(?:;|m)/);
});

test('missing and invalid colors preserve theme fallback styling', () => {
  for (const color of [undefined, '', 'not-a-color']) {
    assert.equal(renderAgentNameLabel('Agent', color, theme), 'Agent');
    assert.equal(
      renderAgentNameLabel('Agent', color, theme, { fallbackColor: 'toolTitle', bold: true }),
      '<toolTitle>\x1b[1mAgent\x1b[22m</toolTitle>',
    );
  }
});
