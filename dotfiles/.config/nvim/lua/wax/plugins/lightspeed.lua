require("lightspeed").setup({
  exit_after_idle_msecs = { labeled = nil, unlabeled = 500 },

  -- s/x
  grey_out_search_area = true,
  highlight_unique_chars = false,
  match_only_the_start_of_same_char_seqs = true,
  jump_on_partial_input_safety_timeout = 400,

  -- Leaving the appropriate list empty effectively disables
  -- "smart" mode, and forces auto-jump to be on or off.
  safe_labels = {},
  labels = {},

  -- f/t
  limit_ft_matches = 4,
})
