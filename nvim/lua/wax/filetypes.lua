local jinja_regex =
  [[{{.*}}\|{%-\?\s*\(end.*\|extends\|block\|macro\|set\|if\|for\|include\|trans\)\>]]

-- Template files (jinja `.j2`, terraform `.tftpl`) are typed by the name they render to, e.g.
-- `values.yaml.j2` as yaml or `Caddyfile.j2` as caddyfile.
local function filetype_of_rendered(path, bufnr)
  local rendered = path:gsub("%.[^./]+$", "")
  return vim.filetype.match({ filename = rendered, buf = bufnr })
end

vim.filetype.add({
  extension = {
    ["json"] = "jsonc",
    ["JSON"] = "jsonc",

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
      if vim.regex(jinja_regex):match_str(content) then
        return "jinja"
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

    -- systemd units, also outside /etc/systemd (e.g. ansible role files)
    ["service"] = "systemd",
    ["timer"] = "systemd",
    ["socket"] = "systemd",
    ["mount"] = "systemd",
    ["container"] = "systemd", -- podman quadlet

    ["cnf"] = "dosini", -- openssl.cnf

    -- templates
    ["j2"] = filetype_of_rendered,
    ["tftpl"] = filetype_of_rendered,

    -- edgeql
    ["esdl"] = "edgeql",
  },
  filename = {
    -- git
    [".gitconfig"] = "config",
    [".gitignore"] = "config",
    -- ini
    [".flake8"] = "ini",
    -- yaml
    [".ansible-lint"] = "yaml",
    -- sh
    ["cronfile"] = "sh",
    [".flaskenv"] = "sh",
    [".aliases"] = "zsh",
    --
    [".nuxtrc"] = "config",
    ["config"] = "config",
    ["Justfile"] = "just",
    ["justfile"] = "just",
    ["Caddyfile"] = "caddyfile",
  },
  -- pattern = map_pattern_ft,
  pattern = {
    [".*%.env.*"] = "sh",
    [".*%.tfvars%.example"] = "terraform",
    [".*unattended%-upgrades.*"] = "aptconf",
  },
})
