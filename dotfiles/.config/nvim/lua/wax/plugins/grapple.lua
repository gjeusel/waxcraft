local grapple = require("grapple")
local scope = require("grapple.scope")

grapple.setup({
  ---@type "debug" | "info" | "warn" | "error"
  -- log_level = waxopts.loglevel,
  log_level = "debug",

  ---The scope used when creating, selecting, and deleting tags
  scope = function()
    -- TODO: need ctx from scope (bufnr from which triggered)
    -- local bufnr = vim.api.nvim_get_current_buf()
    -- local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
    -- if vim.tbl_contains({ "startify" }, filetype) then
    --   return scope.Scope.global
    -- else
    --   return find_root_dir(vim.fn.getcwd())
    -- end
    return find_root_dir(vim.fn.getcwd())
  end,

  ---The save location for tags
  save_path = vim.fn.stdpath("data") .. "/" .. "grapple.json",

  ---Window options used for the popup menu
  popup_options = {
    relative = "editor",
    width = 60,
    height = 12,
    style = "minimal",
    focusable = false,
    border = "single",
  },

  integrations = {
    ---Support for saving tag state using resession.nvim
    resession = false,
  },
})

-- vim.keymap.set("n", "<M-1>", grapple.tag)
-- vim.keymap.set("n", "<C-w><1>", grapple.popup_tags)
vim.keymap.set("n", "<leader>tt", grapple.toggle)
vim.keymap.set("n", "<leader>tl", grapple.popup_tags)
vim.keymap.set("n", "<leader>tk", grapple.popup_scopes)

local map_opt_idx = {
  ["¡"] = 1, -- option + 1
  ["™"] = 2, -- option + 2
  ["£"] = 3, -- option + 3
  ["¢"] = 4, -- option + 4
  ["∞"] = 5, -- option + 5
}
for keymap, grapple_key in pairs(map_opt_idx) do
  vim.keymap.set({ "n", "i", "x" }, keymap, function()
    grapple.select({ key = grapple_key })
  end)
end
