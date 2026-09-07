import type { Readable } from 'node:stream';
import { StdinBuffer } from '@earendil-works/pi-tui';

export function observeFocusInput(input: Readable, onFocus: (focused: boolean) => void): () => void {
  const buffer = new StdinBuffer();
  buffer.on('data', (data) => {
    if (data === '\x1b[I') onFocus(true);
    else if (data === '\x1b[O') onFocus(false);
  });

  // Fullscreen Pi consumes focus reports before extension terminal-input handlers run. Observe stdin
  // without consuming it, and parse complete sequences so bracketed paste cannot change focus.
  const onData = (data: string | Buffer) => buffer.process(data);
  input.on('data', onData);
  return () => {
    input.off('data', onData);
    buffer.destroy();
  };
}
