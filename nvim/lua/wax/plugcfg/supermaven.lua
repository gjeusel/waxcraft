local log_level = "off"
if vim.tbl_contains({ "trace", "debug", "info" }, waxopts.loglevel) then
  log_level = waxopts.loglevel
end

require("supermaven-nvim").setup({
  keymaps = {
    accept_suggestion = "<C-space>",
    clear_suggestion = "<C-]>",
    accept_word = "<C-j>",
  },
  ignore_filetypes = { ["dap-repl"] = true, jsonc = true, json = true },
  condition = function()
    local fpath = vim.api.nvim_buf_get_name(0)

    -- Disable on sensitive dotfiles (e.g. ~/.zshrc, ~/.ssh/config, ~/.env)
    local home = vim.env.HOME or ""
    if home ~= "" then
      local sensitive_patterns = {
        "^" .. vim.pesc(home) .. "/%.zshrc",
        "^" .. vim.pesc(home) .. "/%.zshenv",
        "^" .. vim.pesc(home) .. "/%.zprofile",
        "^" .. vim.pesc(home) .. "/%.bashrc",
        "^" .. vim.pesc(home) .. "/%.bash_profile",
        "^" .. vim.pesc(home) .. "/%.profile",
        "^" .. vim.pesc(home) .. "/%.ssh/",
        "^" .. vim.pesc(home) .. "/%.gnupg/",
        "^" .. vim.pesc(home) .. "/%.aws/",
        "^" .. vim.pesc(home) .. "/%.kube/",
        "^" .. vim.pesc(home) .. "/%.docker/",
        "%.env$",
        "%.env%.local$",
        "%.env%.production$",
        "%.env%.development$",
        "%.pem$",
        "%.key$",
        "/%.secrets",
      }
      for _, pattern in ipairs(sensitive_patterns) do
        if fpath:match(pattern) then
          return true
        end
      end
    end

    return is_big_file(fpath)
  end,
  log_level = log_level,
})

-- Use custom highlight group for inline suggestions
local preview = require("supermaven-nvim.completion_preview")
preview.suggestion_group = "SupermavenSuggestion"
