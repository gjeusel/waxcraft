# hunk — keybindings cheatsheet

TUI diff review tool (`~/src/hunk`).

## Navigation

| Key                              | Action                                                |
| -------------------------------- | ----------------------------------------------------- |
| `↑` / `↓`, `k` / `j`, `Ctrl+Y/E` | Move line-by-line                                     |
| `Ctrl+B/F`, `PgUp` / `PgDn`      | Page up / down                                        |
| `Ctrl+U/D`                       | Half page up / down                                   |
| `[` / `]`                        | Previous / next hunk                                  |
| `,` / `.`, `Ctrl+P/N`            | Previous / next file                                  |
| `{` / `}`, `N` / `n`             | Previous / next annotated hunk (comment)              |
| `←` / `→`                        | Scroll code left / right (`Shift` = 8 cols at a time) |
| `g` / `G`                        | Jump to top / bottom (less-style)                     |
| `Home` / `End`                   | Jump to top / bottom                                  |

## Mouse

| Input         | Action                   |
| ------------- | ------------------------ |
| Wheel         | Scroll vertically        |
| `Shift`+Wheel | Scroll code horizontally |

## View

| Key             | Action                                     |
| --------------- | ------------------------------------------ |
| `1` / `2` / `0` | Layout: split / stack / auto               |
| `s`             | Toggle sidebar                             |
| `t`             | Theme selector                             |
| `a`             | Toggle AI (agent) notes                    |
| `Space` / `z`   | Toggle unchanged context for selected hunk |
| `l`             | Toggle line numbers                        |
| `w`             | Toggle line wrap                           |
| `m`             | Toggle hunk headers (metadata)             |
| `M`             | Toggle menu bar                            |
| `e`             | Open selected file in `$EDITOR`            |

## Review

| Key      | Action                                                                 |
| -------- | ---------------------------------------------------------------------- |
| `/`      | Focus file filter                                                      |
| `Tab`    | Toggle files / filter focus                                            |
| `c`      | Create review note                                                     |
| `Ctrl+S` | Save draft note (while editing)                                        |
| `Esc`    | Cancel draft note / close dialog / close menu                          |
| `F10`    | Open menus (`←`/`→` or `Tab` to switch, `↑`/`↓` + `Enter` to activate) |
| `r`      | Reload current input (when available)                                  |
| `?`      | Toggle help                                                            |
| `q`      | Quit                                                                   |

## Theme selector

| Key               | Action                            |
| ----------------- | --------------------------------- |
| `↑` / `↓` / `Tab` | Move selection (`Shift+Tab` = up) |
| `Enter`           | Accept theme                      |
| `Esc`             | Cancel                            |

## Pager mode

Reduced key set: scrolling (`j`/`k`, `Ctrl+E`/`Ctrl+Y`, `Ctrl+F`/`Ctrl+B`, `Ctrl+D`/`Ctrl+U`, `g`/`G`, arrows, `Home`/`End`), `w` wrap, `s` sidebar, `q` quit.
