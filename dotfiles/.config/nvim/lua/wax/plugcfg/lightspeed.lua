-- disable remaps of lightspeed for f/t
vim.g.lightspeed_no_default_keymaps = true

require("lightspeed").setup({
  exit_after_idle_msecs = { labeled = nil, unlabeled = 500 },

  -- s/x
  -- graywash = true,
  match_only_the_start_of_same_char_seqs = true,
  jump_to_unique_chars = { safety_timeout = 400 },

  -- Leaving the appropriate list empty effectively disables
  -- "smart" mode, and forces auto-jump to be on or off.
  safe_labels = {},
  labels = {},

  -- f/t
  limit_ft_matches = 4,
})

vim.keymap.set("n", "s", "<Plug>Lightspeed_s")
vim.keymap.set("n", "S", "<Plug>Lightspeed_S")
