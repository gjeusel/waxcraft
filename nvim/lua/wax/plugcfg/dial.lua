local augend = require("dial.augend")

require("dial.config").augends:register_group({
  default = {
    augend.integer.alias.decimal,
    augend.integer.alias.hex,
    augend.date.alias["%Y/%m/%d"],
    augend.date.alias["%Y-%m-%d"],
    augend.date.alias["%m/%d/%Y"],
    augend.date.alias["%H:%M:%S"],
    augend.date.alias["%H:%M"],
    augend.constant.alias.bool,
    augend.semver.alias.semver,
  },
})

local dial_map = require("dial.map")
vim.keymap.set("n", "<C-a>", dial_map.inc_normal(), { desc = "Increment (number/date/bool)" })
vim.keymap.set("n", "<C-x>", dial_map.dec_normal(), { desc = "Decrement (number/date/bool)" })
vim.keymap.set("v", "<C-a>", dial_map.inc_visual(), { desc = "Increment (number/date/bool)" })
vim.keymap.set("v", "<C-x>", dial_map.dec_visual(), { desc = "Decrement (number/date/bool)" })
vim.keymap.set("v", "g<C-a>", dial_map.inc_gvisual(), { desc = "Increment sequentially" })
vim.keymap.set("v", "g<C-x>", dial_map.dec_gvisual(), { desc = "Decrement sequentially" })
