local jinja_regex =
  [[{{.*}}\|{%-\?\s*\(end.*\|extends\|block\|macro\|set\|if\|for\|include\|trans\)\>]]

vim.filetype.add({
  extension = {
    ["json"] = "jsonc",
    ["md"] = "markdown",
    ["txt"] = "sh",
    ["conf"] = "config",
    ["nix"] = "nix",

    ["plist"] = "xml", -- macos PropertyList files

    -- frontend
    ["ts"] = "typescript",
    ["html"] = function(_, bufnr)
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
      local content = table.concat(lines, "\n")
      if vim.filetype.matchregex(content, jinja_regex) then
        return "jinja.html"
      else
        return "html"
      end
    end,

    -- yamls
    ["kubeconfig"] = "yaml",
    ["yml"] = "yaml",

    -- terraform
    ["tf"] = "terraform",
    ["tfvars"] = "terraform",
    ["tfstate"] = "terraform",

    -- edgeql
    ["esdl"] = "edgeql",
  },
  filename = {
    -- git
    [".gitconfig"] = "config",
    [".gitignore"] = "config",
    -- ini
    [".flake8"] = "ini",
    -- sh
    ["cronfile"] = "sh",
    [".flaskenv"] = "sh",
    [".aliases"] = "zsh",
  },
  -- pattern = map_pattern_ft,
  pattern = {
    [".*%.env.*"] = "sh",
  },
})
