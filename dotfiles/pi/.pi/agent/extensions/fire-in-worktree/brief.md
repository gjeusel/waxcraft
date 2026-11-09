# Fire in worktree

The user handed off the task below with "fire in worktree". The conversation above is where it was
discussed. You continue that conversation in an isolated git worktree and carry this task through
to a merge request on your own. Other tasks discussed above, if any, belong to sibling agents: do
only this one.

Nobody watches this session. Do not stop for questions you can settle from the code or the
conversation: decide, and record the assumption in the MR description. Do not block on
`ask_user_question`. Stop early only when continuing would be unsafe or impossible, and explain why
in your final message.

## Request

{{request}}

## Brief from the launching session

{{task}}

## Workspace

- Your working directory is the worktree `{{worktree}}`, a linked worktree of the agent-only clone
  `{{clone}}`. Edit, run commands, and commit only here.
- `{{userCheckout}}` is the user's own checkout: never edit it, run git commands in it, or use its
  `.venv`. Paths under it in the conversation above refer to the same files in this worktree. Leave
  `{{clone}}` alone too, apart from the `wt` commands below.
- Issue: {{issue}}
- MR: {{mr}}
- Branch: {{branch}} Keep it: its name is the glab skill's canonical name for the issue.
- Setup: {{setup}}
- Python: a uv project's worktree has its own `.venv`, created by
  `UV_LINK_MODE=symlink uv sync --frozen --all-extras`. Use it (`uv run ...`), never a conda
  environment or another checkout's venv. Rerun that command after changing dependencies.
- Unreleased code of a sibling repository: when the task needs a branch of another repository that
  is not merged and released yet (for example, venturi needing an unmerged zefire branch), give that
  branch its own worktree and install it in editable mode into this venv only:
  1. `test -d ~/.pi/src/<repo> || git clone --reference ~/src/<repo> --dissociate <origin-url> ~/.pi/src/<repo>`
  2. `wt -C ~/.pi/src/<repo> switch <branch> --no-cd --yes < /dev/null`
  3. `uv pip install --no-deps -e ~/.pi/src/<repo>.worktrees/<branch>`, where a `/` in the branch
     name becomes `-`

  Do not change `pyproject.toml` or `uv.lock` for it. Run commands with `uv run --no-sync`: a plain
  `uv run` or `uv sync` reinstalls the locked release. Name the dependency in the MR description.

## Authorization

For this task only, the user authorizes the complete GitLab flow on this worktree's branch: staging,
committing, pushing it, and updating its MR. This overrides the default rule against
committing or pushing. Never force-push, rewrite published history, or touch other branches or MRs.

## Workflow

1. **Implement** the change, following the repository's `AGENTS.md`, and run the checks the change
   can affect.
2. **Review with the other provider.** {{reviewStep}}
3. **Publish**, yourself, without a subagent:
   1. Commit the task's changes on this branch as the glab skill's workflow section "Commit, push,
      verify" prescribes, its staged-tree and hook checks included. Everything pending in this
      worktree belongs to the task; gitignored files stay out.
   2. Write the MR description to a file outside the worktree, following the glab skill's
      `references/templates.md`: **What**, then **Notes for the reviewer** when useful, including the
      dismissed review findings with their reason.
   3. From the worktree, run
      `python3 {{glabTask}} publish --issue {{issueIid}} --description-file <file> --ready`.
      It pushes, sets the MR description with `Closes #{{issueIid}}` first, marks the MR ready for
      review, and verifies the result. When the work is unfinished, or a check fails because of the
      change, leave out `--ready`: the MR stays a draft, and your final message says why.

   {{mergeStep}} Never mention AI or agents in commits, the MR, or the issue.
4. **Final message:** the MR link, the checks run and their results, and the review outcome.
