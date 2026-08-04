import { CustomEditor, type ExtensionAPI } from '@earendil-works/pi-coding-agent';
import type { EditorComponent, TUI } from '@earendil-works/pi-tui';

const ENABLE_FOCUS_REPORTING = '\x1b[?1004h';
const DISABLE_FOCUS_REPORTING = '\x1b[?1004l';
const FOCUS_EVENT_PATTERN = /\x1b\[([IO])/g;

async function isCurrentTmuxPaneFocused(pi: ExtensionAPI): Promise<boolean> {
  const pane = process.env.TMUX_PANE;
  if (!process.env.TMUX || !pane) return true;

  const result = await pi.exec(
    'tmux',
    ['display-message', '-p', '-t', pane, '#{pane_active}|#{window_active}|#{client_flags}'],
    { timeout: 1000 },
  );
  if (result.code !== 0) return true;

  const [paneActive, windowActive, clientFlags = ''] = result.stdout.trim().split('|', 3);
  return paneActive === '1' && windowActive === '1' && clientFlags.split(',').includes('focused');
}

function createFocusAwareEditor(
  editor: EditorComponent,
  inactiveBorderColor: (text: string) => string,
  isFocused: () => boolean,
): EditorComponent {
  const render = editor.render.bind(editor);

  editor.render = (width: number): string[] => {
    if (isFocused() || !editor.borderColor) return render(width);

    const activeBorderColor = editor.borderColor;
    editor.borderColor = inactiveBorderColor;
    try {
      return render(width);
    } finally {
      editor.borderColor = activeBorderColor;
    }
  };

  return editor;
}

export default function (pi: ExtensionAPI) {
  let tui: TUI | undefined;
  let unsubscribe: (() => void) | undefined;

  const disableFocusReporting = () => tui?.terminal.write(DISABLE_FOCUS_REPORTING);

  pi.on('session_start', async (_event, ctx) => {
    if (ctx.mode !== 'tui' || !process.env.TMUX || !process.env.TMUX_PANE) return;

    let focused = true;
    let focusEventSeen = false;
    const previousEditorFactory = ctx.ui.getEditorComponent();

    unsubscribe = ctx.ui.onTerminalInput((data) => {
      let nextFocused = focused;
      const remaining = data.replace(FOCUS_EVENT_PATTERN, (_sequence, event: string) => {
        focusEventSeen = true;
        nextFocused = event === 'I';
        return '';
      });

      if (nextFocused === focused && remaining === data) return;
      if (nextFocused !== focused) {
        focused = nextFocused;
        tui?.requestRender();
      }

      return remaining.length === 0 ? { consume: true } : { data: remaining };
    });

    ctx.ui.setEditorComponent((nextTui, theme, keybindings) => {
      tui = nextTui;
      const editor =
        previousEditorFactory?.(nextTui, theme, keybindings) ?? new CustomEditor(nextTui, theme, keybindings);
      return createFocusAwareEditor(
        editor,
        (text) => ctx.ui.theme.fg('dim', text),
        () => focused,
      );
    });

    tui?.terminal.write(ENABLE_FOCUS_REPORTING);
    process.once('exit', disableFocusReporting);

    const initiallyFocused = await isCurrentTmuxPaneFocused(pi);
    if (!focusEventSeen && initiallyFocused !== focused) {
      focused = initiallyFocused;
      tui?.requestRender();
    }
  });

  pi.on('session_shutdown', () => {
    process.off('exit', disableFocusReporting);
    unsubscribe?.();
    unsubscribe = undefined;
    disableFocusReporting();
    tui = undefined;
  });
}
