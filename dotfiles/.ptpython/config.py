"""
Configuration example for ``ptpython``.

Copy this file to $XDG_CONFIG_HOME/ptpython/config.py
"""

from __future__ import unicode_literals

from prompt_toolkit.filters import ViInsertMode
from prompt_toolkit.key_binding.key_processor import KeyPress
from prompt_toolkit.keys import Keys
from prompt_toolkit.styles.pygments import style_from_pygments_cls
from ptpython.layout import CompletionVisualisation
from pygments.style import Style
from pygments.token import Comment, Generic, Keyword, Name, Number, Operator, String, Token


class GruvboxStyle(Style):
    """Retro groove color scheme for Vim by Github: @morhetz"""

    background_color = "#282828"
    styles = {
        Comment.Preproc: "noinherit #8ec07c",
        Comment: "#928374 italic",
        Generic.Deleted: "noinherit #282828",
        Generic.Emph: "#83a598 underline",
        Generic.Error: "#fb4934 bold",
        Generic.Heading: "#b8bb26 bold",
        Generic.Inserted: "noinherit #282828",
        Generic.Output: "noinherit #504945",
        Generic.Prompt: "#ebdbb2",
        Generic.Strong: "#ebdbb2",
        Generic.Subheading: "#b8bb26 bold",
        Generic.Traceback: "#fb4934 bold",
        Generic: "#ebdbb2",
        Keyword.Type: "noinherit #fabd2f",
        Keyword: "noinherit #fe8019",
        Name.Attribute: "#b8bb26 bold",
        Name.Builtin: "#fabd2f",
        Name.Constant: "noinherit #d3869b",
        Name.Entity: "noinherit #fabd2f",
        Name.Exception: "noinherit #fb4934",
        Name.Function: "#fabd2f",
        Name.Label: "noinherit #fb4934",
        Name.Tag: "noinherit #fb4934",
        Name.Variable: "noinherit #ebdbb2",
        Name: "#ebdbb2",
        Number.Float: "noinherit #d3869b",
        Number: "noinherit #d3869b",
        Operator: "#fe8019",
        String.Symbol: "#83a598",
        String: "noinherit #b8bb26",
        Token: "noinherit #ebdbb2",
    }


__all__ = ("configure",)


def configure(repl):
    """
    Configuration method. This is called during the start-up of ptpython.

    :param repl: `PythonRepl` instance.
    """
    # Show function signature (bool).
    repl.show_signature = True

    # Show docstring (bool).
    repl.show_docstring = False

    # Show the "[Meta+Enter] Execute" message when pressing [Enter] only
    # inserts a newline instead of executing the code.
    repl.show_meta_enter_message = False

    # Show completions. (NONE, POP_UP, MULTI_COLUMN or TOOLBAR)
    repl.completion_visualisation = CompletionVisualisation.POP_UP

    # When CompletionVisualisation.POP_UP has been chosen, use this
    # scroll_offset in the completion menu.
    repl.completion_menu_scroll_offset = 0

    # Show line numbers (when the input contains multiple lines.)
    repl.show_line_numbers = True

    # Show status bar.
    repl.show_status_bar = False

    # When the sidebar is visible, also show the help text.
    repl.show_sidebar_help = False

    # Swap light/dark colors on or off
    repl.swap_light_and_dark = False

    # Highlight matching parethesis.
    repl.highlight_matching_parenthesis = True

    # Line wrapping. (Instead of horizontal scrolling.)
    repl.wrap_lines = True

    # Mouse support.
    repl.enable_mouse_support = False

    # Complete while typing. (Don't require tab before the completion menu is shown.)
    repl.complete_while_typing = False

    # Fuzzy and dictionary completion.
    repl.enable_fuzzy_completion = True
    repl.enable_dictionary_completion = True

    # Vi mode.
    repl.vi_mode = False

    # Paste mode. (When True, don't insert whitespace after new line.)
    repl.paste_mode = False

    # Use the classic prompt. (Display '>>>' instead of 'In [1]'.)
    repl.prompt_style = "classic"  # 'classic' or 'ipython'

    # Don't insert a blank line after the output.
    repl.insert_blank_line_after_output = False

    # History Search.
    # When True, going back in history will filter the history on the records
    # starting with the current input. (Like readline.)
    # Note: When enable, please disable the `complete_while_typing` option.
    #       otherwise, when there is a completion available, the arrows will
    #       browse through the available completions instead of the history.
    repl.enable_history_search = True

    # Enable auto suggestions. (Pressing right arrow will complete the input,
    # based on the history.)
    repl.enable_auto_suggest = True

    # Typing 'ctrl-space' will accept auto-complete
    @repl.add_key_binding("c-space")
    def _(event):
        "Map 'ctrl-space' to 'ctrl-e'."
        event.cli.key_processor.feed(KeyPress(Keys.ControlE))

    # Enable open-in-editor. Pressing C-X C-E in emacs mode or 'v' in
    # Vi navigation mode will open the input in the current editor.
    repl.enable_open_in_editor = True

    # Enable system prompt. Pressing meta-! will display the system prompt.
    # Also enables Control-Z suspend.
    repl.enable_system_bindings = True

    # Ask for confirmation on exit.
    repl.confirm_exit = False

    # Enable input validation. (Don't try to execute when the input contains
    # syntax errors.)
    repl.enable_input_validation = True

    # Use this colorscheme for the code.
    # repl.use_code_colorscheme('pastie')
    # repl.install_code_colorscheme("gruvbox", GruvboxStyle.styles)
    gruvbox = style_from_pygments_cls(GruvboxStyle)
    repl.code_styles["gruvbox"] = gruvbox
    repl.use_code_colorscheme("gruvbox")

    # Set color depth (keep in mind that not all terminals support true color).
    # repl.color_depth = 'DEPTH_1_BIT'  # Monochrome.
    # repl.color_depth = 'DEPTH_4_BIT'  # ANSI colors only.
    repl.color_depth = "DEPTH_8_BIT"  # The default, 256 colors.
    # repl.color_depth = 'DEPTH_24_BIT'  # True color.

    # Syntax.
    repl.enable_syntax_highlighting = True

    # Typing 'jj' in Vi Insert mode, should send escape. (Go back to navigation
    # mode.)
    @repl.add_key_binding("j", "j", filter=ViInsertMode())
    def _(event):
        "Map 'jj' to Escape."
        event.cli.key_processor.feed(KeyPress(Keys.Escape))

    # Custom key binding for some simple autocorrection while typing.
    corrections = {
        "mport": "import",
        "impotr": "import",
        "pritn": "print",
    }

    @repl.add_key_binding(" ")
    def _(event):
        "When a space is pressed. Check & correct word before cursor."
        b = event.cli.current_buffer
        w = b.document.get_word_before_cursor()

        if w is not None:
            if w in corrections:
                b.delete_before_cursor(count=len(w))
                b.insert_text(corrections[w])

        b.insert_text(" ")
