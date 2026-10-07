/** OpenAI Codex priority routing and server-side encrypted context compaction. */
import { join } from 'node:path';
import { getAgentDir, type ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { registerCodexCompaction } from './compaction.ts';
import { registerFastMode } from './fast.ts';

export default function (pi: ExtensionAPI): void {
  registerFastMode(pi, join(getAgentDir(), 'pi-openai.json'));
  registerCodexCompaction(pi);
}
