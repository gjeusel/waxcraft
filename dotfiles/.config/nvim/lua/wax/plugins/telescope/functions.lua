local builtin = require("telescope.builtin")

local M = {}

---Find Files with git files first.
---@param opts table
M.ffile = function(opts)
  opts = vim.tbl_extend("force", {
    hidden = true,
    git_files = true,
    path_display = {
      truncate = 3,
      -- smart = true, -- slow
    },
    cwd = vim.loop.cwd(),
  }, opts or {})

  if opts.git_files and is_git(opts.cwd) then
    opts = vim.tbl_extend("force", { prompt_title = "~ git files ~" }, opts)
    return builtin.git_files(opts)
  else
    opts = vim.tbl_extend("force", {
      prompt_title = "~ files ~",
      no_ignore = true,
      cwd = find_root_dir(opts.cwd),
    }, opts)
    return builtin.find_files(opts)
  end
end

---Dotfiles find file
M.wax_file = function()
  local opts = {
    prompt_title = "~ dotfiles waxdir ~",
    search_dirs = {
      "~/src/waxcraft",
      "~/.config/nvim",
      "~/.local/share/nvim/site/pack/packer",
      -- Local not versioned in dotfiles:
      "~/.gitconfig",
      "~/.python_startup_local.py",
      "~/.zshrc",
    },
    git_files = false,
  }
  M.ffile(opts)
end

-- Projects grep string
-- Add all M commands to builtin for the builtin.builtin leader b search
for key, value in pairs(M) do
  builtin[key] = value
end

-- Fallback to builtin
return setmetatable({}, {
  __index = function(_, k)
    if M[k] then
      return M[k]
    else
      return require("telescope.builtin")[k]
    end
  end,
})
