/** Provider-aware Fast mode and OpenAI Codex server-side encrypted context compaction. */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { registerCodexCompaction } from './compaction.ts';
import { registerFastMode } from './fast.ts';

export default function (pi: ExtensionAPI): void {
  registerFastMode(pi);
  registerCodexCompaction(pi);
}
