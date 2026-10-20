/** Provider-aware Fast mode and OpenAI Codex / Anthropic server-side context compaction. */
import type { ExtensionAPI } from '@earendil-works/pi-coding-agent';
import { registerAnthropicCompaction, registerCodexCompaction } from './compaction.ts';
import { registerFastMode } from './fast.ts';

export default function (pi: ExtensionAPI): void {
  registerFastMode(pi);
  registerCodexCompaction(pi);
  // After Codex: its handler cancels compaction over opaque Codex history before this one runs.
  registerAnthropicCompaction(pi);
}
