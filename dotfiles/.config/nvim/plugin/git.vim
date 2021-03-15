set signcolumn=yes
let g:conflict_marker_enable_mappings = 0
let g:gitgutter_max_signs = 200
let g:gitgutter_sign_added = '•'
let g:gitgutter_sign_modified = '•'
let g:gitgutter_sign_removed = '•'
let g:gitgutter_sign_removed_first_line = '•'
let g:gitgutter_sign_modified_removed = '•'


"" gitconfig:
""
"[core]
"  editor = nvim
"[merge]
"  tool = vimdiff
"[mergetool]
"  prompt = false
"[mergetool "vimdiff"]
"  cmd = nvim -d $LOCAL $REMOTE $MERGED -c '$wincmd w' -c 'wincmd J'
"[difftool]
"  prompt=false
"[diff]
"  path = vimdiff
