require("Comment").setup({
  ignore = "^$",
  sticky = true,
  toggler = {
    -- line-comment keymap
    line = "<leader>cc",
    ---block-comment keymap
    -- block = "gbc",
  },
  opleader = {
    -- line-comment keymap
    line = "<leader>c",
    -- block-comment keymap
    -- block = "<leader>b",
  },
  mappings = {
    basic = true,
    extra = false,
    extended = false,
  },
  pre_hook = function(_)
    if vim.bo.filetype == "vue" then
      require("ts_context_commentstring.internal").update_commentstring()
    end
  end,
})
