#self: super:


with import <nixpkgs> {};

vim_configurable.customize {
    # Specifies the vim binary name.
    # E.g. set this to "my-vim" and you need to type "my-vim" to open this vim
    # This allows to have multiple vim packages installed (e.g. with a different set of plugins)
    name = "my-vim";

    vimrcConfig.vam.pluginDictionaries = [
        { names = [
            # They are installed managed by `vam` (a vim plugin manager)

            # Good Looking vim :
            "colors-solarized"
            "Solarized"
            "airline"
            "vim-airline-themes"

            # Usefull tools :
            "nerdtree"
            "surround"
            "repeat"
            "auto-pairs"
            "ctrlp"
            "deoplete-jedi"
        ]; }
    ];

    vimrcConfig.customRC = ''

" Automatic reloading of .vimrc
autocmd! bufwritepost .vimrc source %

" Rebind <Leader> key
let mapleader = ","

" Color scheme
set t_Co=256
color solarized"

" Useful settings
"" set history=700
"" set undolevels=700

" Enable syntax highlighting
" You need to reload this file for the change to apply
filetype off
filetype plugin indent on
syntax on

" Disable indent highlighting
let g:indent_guides_enable_on_vim_startup=0
let g:indent_guides_auto_colors = 0

" Rainbow plugin : (parenthesis and brackets colored by level)
let g:rainbow_active = 1

" Disable auto-pairs:
"let b:AutoPairs = {"(": ")"}

" Vim-airline plugin
let g:airline_theme = 'solarized'

"Automatically displays all buffers when there's only one tab open :
let g:airline#extensions#tabline#enabled = 1


" Use local vimrc if available {
    if filereadable(expand("~/.vimrc.local"))
        source ~/.vimrc.local
    endif
" }

" Use spf13 vimrc if available {
    if filereadable(expand("~/.vimrc.spf13"))
        source ~/.vimrc.spf13
    endif
" }
    '';
}
