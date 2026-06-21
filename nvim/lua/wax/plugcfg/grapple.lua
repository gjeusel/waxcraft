local grapple = require("grapple")

local loglevel = waxopts.loglevel
if loglevel == "trace" then
  loglevel = "debug"
end

local function project_resolver()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients > 0 then
    return clients[1].config.root_dir
  else
    return find_root_dir(vim.fn.getcwd()) or vim.fn.getcwd()
  end
end

local function git_branch_resolver()
  -- TODO: this will stop on submodules, needs fixing
  local git_files = vim.fs.find(".git", { upward = true, stop = vim.uv.os_homedir() })
  if #git_files == 0 then
    return
  end

  local root = vim.fn.fnamemodify(git_files[1], ":h")

  -- TODO: Don't use vim.system, it's a nvim-0.10 feature
  -- TODO: Don't shell out, read the git head or something similar
  local result = vim.fn.system({ "git", "symbolic-ref", "--short", "HEAD" })
  local branch = vim.trim(string.gsub(result, "\n", ""))

  local id = string.format("%s:%s", root, branch)
  local path = root

  return id, path
end

grapple.setup({
  ---@type "debug" | "info" | "warn" | "error"
  log_level = loglevel,

  scope = "no-cache-gitbranch", -- also try out "git_branch"
  scopes = {
    {
      name = "project",
      fallback = "cwd",
      cache = { "DirChanged" },
      resolver = project_resolver,
    },
    {
      name = "no-cache-gitbranch",
      fallback = "project",
      cache = {},
      resolver = git_branch_resolver,
    },
  },

  ---Window options used for the popup menu
  win_opts = {
    relative = "editor",
    width = 80,
    height = 6,
    style = "minimal",
    focusable = false,
    border = "single",
  },
})

local function orderby_grapple_tags()
  local state = require("barbar.state")
  local render = require("barbar.ui.render")

  -- grapple tag path -> position in the tag list
  local tag_index = {}
  for i, tag in ipairs(grapple.tags() or {}) do
    tag_index[tag.path] = i
  end

  -- Capture the current order so untagged buffers keep their relative position.
  -- table.sort is NOT stable; without this, untagged buffers reshuffle on every
  -- call (and a comparator that mixes criteria isn't a strict-weak-ordering),
  -- which is what makes the bar flicker.
  local current = {}
  for i, bufnr in ipairs(state.buffers) do
    current[bufnr] = i
  end

  -- Rank: tagged buffers first by grapple index, everything else after them
  -- in its existing order. Returns a (primary, secondary) tuple for a total order.
  local function rank(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) then
      local idx = tag_index[vim.api.nvim_buf_get_name(bufnr)]
      if idx then
        return idx, 0
      end
    end
    return math.huge, current[bufnr] or math.huge
  end

  table.sort(state.buffers, function(left, right)
    local left_primary, left_secondary = rank(left)
    local right_primary, right_secondary = rank(right)
    if left_primary ~= right_primary then
      return left_primary < right_primary
    end
    return left_secondary < right_secondary
  end)
  render.update()
end

vim.keymap.set("n", "<leader>tt", function()
  grapple.unload()
  grapple.toggle()
end)
vim.keymap.set("n", "<leader>tl", function()
  grapple.unload()
  grapple.toggle_tags()
end)

vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
  pattern = "*",
  callback = function(args)
    local filetype = vim.bo[args.buf].filetype
    if filetype == "grapple" then
      orderby_grapple_tags()
    end
  end,
})

local map_opt_idx = {
  ["¡"] = 1, -- option + 1
  ["™"] = 2, -- option + 2
  ["£"] = 3, -- option + 3
  ["¢"] = 4, -- option + 4
  ["∞"] = 5, -- option + 5
}
for keymap, grapple_key in pairs(map_opt_idx) do
  vim.keymap.set({ "n", "i", "x" }, keymap, function()
    if grapple.exists({ index = grapple_key }) then
      grapple.select({ index = grapple_key })
      orderby_grapple_tags()
    end
  end)
end
