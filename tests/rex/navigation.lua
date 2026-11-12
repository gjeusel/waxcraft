-- Run from the repository root: just test rex
local bindings = {}
local foreground, listing
local scans, navigations = 0, 0

package.loaded.sessions = { define = function() end }
package.loaded.scrollback = { define = function() end }

rex = {
  action = function() end,
  bind = function(key, callback)
    bindings[key] = callback
  end,
  block = {
    call = function(creator, method, args)
      assert(creator == "com.superlogical.terminal" and method == "process")
      assert(args.block_id == "test-block")

      return { foreground = foreground }
    end,
  },
  exec = function(argv)
    assert(table.concat(argv, " ") == "ps -axo pid=,pgid=,stat=,comm=")
    scans = scans + 1

    return listing
  end,
  invoke = function(action, args)
    assert(action == "navigate")
    navigations = navigations + 1

    return {}, nil
  end,
}

dofile("dotfiles/rex/.config/rex/init.lua")

-- Process-table order is not guaranteed; the editor can precede the Hunk launcher.
local nested_editor = [[
  103 100 S+ /Applications/Neovim App/bin/.nvim-wrapped
  100 100 S+ node
  101 100 S+ /opt/hunk/bin/hunk
  102 100 S+ nvim
]]

local cases = {
  { name = "shell", process = { pid = 100, name = "zsh" } },
  { name = "other Node program", process = { pid = 100, name = "node", script = "/bin/pi" } },
  { name = "Neovim", process = { pid = 100, name = "nvim" }, forward = true },
  { name = "Nix Neovim", process = { pid = 100, name = ".nvim-wrapped" }, forward = true },
  { name = "Vim", process = { pid = 100, name = "vim" }, forward = true },
  { name = "fzf", process = { pid = 100, name = "fzf" }, forward = true },
  { name = "unknown foreground" },
  {
    name = "Hunk Node launcher with editor",
    process = { pid = 100, name = "node", script = "/Users/test/.local/bin/hunk" },
    output = nested_editor,
    forward = true,
    scan = true,
  },
  {
    name = "native Hunk with editor",
    process = { pid = 100, name = "hunk" },
    output = nested_editor,
    forward = true,
    scan = true,
  },
  {
    name = "Hunkdiff with editor in inherited process group",
    process = { pid = 101, name = "hunkdiff" },
    output = nested_editor,
    forward = true,
    scan = true,
  },
  {
    name = "plain Hunk",
    process = { pid = 100, name = "hunk" },
    output = "100 100 S+ hunk\n",
    scan = true,
  },
  {
    name = "unrelated or background editor",
    process = { pid = 100, name = "hunk" },
    output = "100 100 S+ hunk\n103 103 S nvim\n",
    scan = true,
  },
  {
    name = "suspended editor",
    process = { pid = 100, name = "hunk" },
    output = "100 100 S+ hunk\n103 100 T+ nvim\n",
    scan = true,
  },
  {
    name = "zombie editor",
    process = { pid = 100, name = "hunk" },
    output = "100 100 S+ hunk\n103 100 Z nvim\n",
    scan = true,
  },
  {
    name = "launcher exited during scan",
    process = { pid = 100, name = "hunk" },
    output = "103 100 S+ nvim\n",
    scan = true,
  },
  {
    name = "failed ps",
    process = { pid = 100, name = "hunk" },
    failed = true,
    scan = true,
  },
  {
    name = "unavailable ps",
    process = { pid = 100, name = "hunk" },
    unavailable = true,
    scan = true,
  },
}

for _, case in ipairs(cases) do
  for _, key in ipairs({ "h", "j", "k", "l" }) do
    foreground = case.process
    listing = not case.unavailable and { ok = not case.failed, stdout = case.output or "" } or nil
    scans, navigations = 0, 0

    local handled = bindings["ctrl+" .. key]({ block_id = "test-block" })
    local label = case.name .. " (ctrl+" .. key .. ")"
    assert(handled == not case.forward, label .. ": unexpected key handling")
    assert(navigations == (case.forward and 0 or 1), label .. ": unexpected Rex navigation")
    assert(scans == (case.scan and 1 or 0), label .. ": unexpected process scan")
  end
end

print(("Rex navigation: %d cases passed"):format(#cases * 4))
