Mercurial hg cheatsheet
===============

# hg rebase
`hg rebase --base 479 --dest 490`

# undo changes
undo changes for file.py : `hg revert file.py`

# hide commits locally with strip
will hide commits from 490 with all children : `hg strip 490`

# shelve (= git stash)
- `hg shelve`
- `hg unshelve`

# Change phase :
go public for 415 and all children : `hg phase -d -r 415::`

# Histedit (equivalent as git rebase -i):
`hg histedit 415`
