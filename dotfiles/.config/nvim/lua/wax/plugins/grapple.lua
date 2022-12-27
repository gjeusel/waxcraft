local grapple = require("grapple")

grapple.setup({
  ---@type "debug" | "info" | "warn" | "error"
  log_level = waxopts.loglevel,
  -- log_level = "debug",

  ---The scope used when creating, selecting, and deleting tags
  scope = "static",

  ---Window options used for the popup menu
  popup_options = {
    relative = "editor",
    width = 60,
    height = 12,
    style = "minimal",
    focusable = false,
    border = "single",
  },
})

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
    if grapple.exists({ key = grapple_key }) then
      grapple.select({ key = grapple_key })
    end
  end)
end
