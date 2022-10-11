local builtin = require("telescope.builtin")
local actions = require("telescope.actions")
local action_set = require("telescope.actions.set")
local action_state = require("telescope.actions.state")

local M = {}

---Find Files with git files first.
---@param opts table
M.ffile = function(opts)
  opts = vim.tbl_extend("force", { hidden = true, path_display = { truncate = 3 } }, opts or {})

  if opts.git_files and is_git(opts.cwd or vim.loop.cwd()) then
    opts = vim.tbl_extend("force", { prompt_title = "~ git files ~" }, opts)
    builtin.git_files(opts)
  else
    opts = vim.tbl_extend("force", {
      prompt_title = "~ files ~",
      no_ignore = true,
      cwd = find_root_dir(vim.fn.getcwd()),
    }, opts)
    builtin.find_files(opts)
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
  }
  builtin.find_files(opts)
end

-- Projects find file
local project_two_step = function(prompt_title, fn_second_step)
  local scan = require("plenary.scandir")
  local Path = require("plenary.path")
  local os_sep = Path.path.sep

  local conf = require("telescope.config").values
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local make_entry = require("telescope.make_entry")

  local opts = { prompt_title = prompt_title, cwd = "~/src", depth = 1 }

  opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
  opts.new_finder = opts.new_finder
    or function(path)
      opts.cwd = path
      local data = {}

      scan.scan_dir(path, {
        hidden = opts.hidden or false,
        add_dirs = true,
        depth = opts.depth,
        on_insert = function(entry, typ)
          table.insert(data, typ == "directory" and (entry .. os_sep) or entry)
        end,
      })

      local entry_maker_fn = function()
        local gen = make_entry.gen_from_file(opts)
        return function(entry)
          local tmp = gen(entry)
          tmp.ordinal = Path:new(entry):make_relative(opts.cwd)
          return tmp
        end
      end

      return finders.new_table({
        results = data,
        entry_maker = entry_maker_fn(),
      })
    end

  pickers
    .new(opts, {
      prompt_title = "File Browser",
      finder = opts.new_finder(opts.cwd),
      previewer = conf.file_previewer(opts),
      sorter = conf.file_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        action_set.select:replace(function()
          local entry = action_state.get_selected_entry()
          local project = entry[1]
          actions.close(prompt_bufnr)
          fn_second_step({ cwd = project })
          vim.cmd(":normal! A") -- small fix to be in insert mode
          return true
        end)

        return true
      end,
    })
    :find()
end

M.projects_grep_files = function()
  return project_two_step("~ projects files ~", M.ffile)
end

M.projects_grep_string = function()
  return project_two_step("~ projects grep string ~", function(cwd)
    return require("fzf-lua").grep({ cwd = cwd, search = "" })
  end)
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
