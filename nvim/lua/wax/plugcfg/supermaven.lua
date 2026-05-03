local log_level = "off"
if vim.tbl_contains({ "trace", "debug", "info" }, waxopts.loglevel) then
  log_level = waxopts.loglevel
end

-- Filetypes that are almost always sensitive config (shells, env, secrets).
-- Disabled outright via ignore_filetypes — covers symlinked dotfiles regardless of path.
local sensitive_filetypes = {
  ["dap-repl"] = true,
  jsonc = true,
  json = true,
  zsh = true,
  bash = true,
  sh = true,
  fish = true,
  conf = true,
  gitconfig = true,
  netrc = true,
}

local function path_is_sensitive(fpath)
  if not fpath or fpath == "" then
    return false
  end

  local home = vim.env.HOME or ""
  local patterns = {
    -- Shell rc/profile files (matched anywhere — works for ~/.zshrc, ~/.config/zsh/.zshrc, etc.)
    "/%.?zshrc$",
    "/%.?zshenv$",
    "/%.?zprofile$",
    "/%.?zlogin$",
    "/%.?zlogout$",
    "/%.?bashrc$",
    "/%.?bash_profile$",
    "/%.?bash_login$",
    "/%.?bash_logout$",
    "/%.?profile$",
    "/config%.fish$",
    -- Env / secret files
    "/%.envrc$",
    "/%.netrc$",
    "/%.npmrc$",
    "/%.pypirc$",
    "%.env$",
    "%.env%.[%w_-]+$",
    "/secrets",
    "/credentials",
    "%.pem$",
    "%.key$",
    "_rsa$",
    "_ed25519$",
    "_ecdsa$",
    "_dsa$",
    -- sops temp files: $TMPDIR/<numeric>/<filename>
    -- macOS:  /[private/]var/folders/<short>/<hash>/T/<digits>/...
    -- linux:  /tmp/<digits>/...
    "/var/folders/[^/]+/[^/]+/T/%d+/[^/]+$",
    "^/tmp/%d+/[^/]+$",
  }

  -- Filename keyword match (case-insensitive): catches sops-edited files,
  -- vault/age/sealed-secret manifests, etc., regardless of extension or path.
  local basename = fpath:match("([^/]+)$") or ""
  local lower = basename:lower()
  local keywords = { "secret", "sops", "vault", "credential" }
  for _, kw in ipairs(keywords) do
    if lower:find(kw, 1, true) then
      return true
    end
  end

  if home ~= "" then
    local home_dirs = {
      "/%.ssh/",
      "/%.gnupg/",
      "/%.aws/",
      "/%.kube/",
      "/%.docker/",
      "/%.config/zsh/",
      "/%.config/fish/",
      "/%.config/sh/",
      "/%.config/bash/",
      "/%.config/gh/hosts",
      "/%.config/git/credentials",
    }
    local home_pat = vim.pesc(home)
    for _, p in ipairs(home_dirs) do
      table.insert(patterns, "^" .. home_pat .. p)
    end
  end

  for _, pattern in ipairs(patterns) do
    if fpath:match(pattern) then
      return true
    end
  end
  return false
end

require("supermaven-nvim").setup({
  keymaps = {
    accept_suggestion = "<C-space>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = sensitive_filetypes,
  condition = function()
    local bufname = vim.api.nvim_buf_get_name(0)

    -- Resolve symlinks so ~/.zshrc -> ~/.config/zsh/.zshrc is also caught.
    local realpath = bufname
    if bufname ~= "" then
      local ok, resolved = pcall(vim.uv.fs_realpath, bufname)
      if ok and resolved then
        realpath = resolved
      end
    end

    if path_is_sensitive(bufname) or path_is_sensitive(realpath) then
      return true
    end

    return is_big_file(bufname)
  end,
  log_level = log_level,
})

-- Use custom highlight group for inline suggestions
local preview = require("supermaven-nvim.completion_preview")
preview.suggestion_group = "SupermavenSuggestion"
