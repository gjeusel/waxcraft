require("Comment").setup({
  ignore = "^$", -- ignore empty lines
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
  pre_hook = function()
    -- https://github.com/numToStr/Comment.nvim/pull/62#issuecomment-972790418
    -- Fix builtin Comment behaviour by using ts_context_commentstring:
    if vim.tbl_contains({ "vue", "svelte" }, vim.bo.filetype) then
      require("ts_context_commentstring.internal").update_commentstring()
      return vim.o.commentstring
    end

    if vim.bo.filetype == "typescriptreact" then
      local fn = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
      return fn()
    end
  end,
})
