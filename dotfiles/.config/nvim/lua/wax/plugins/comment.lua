local comment_utils = require("Comment.utils")

require("Comment").setup({
  ignore = "^$",
  toggler = {
    ---line-comment keymap
    line = "<leader>cc",
    ---block-comment keymap
    -- block = "gbc",
  },
  opleader = {
    ---line-comment keymap
    line = "<leader>c",
    ---block-comment keymap
    -- block = "<leader>b",
  },
  pre_hook = function(ctx)
    if vim.bo.filetype == "vue" then
      require("ts_context_commentstring.internal").update_commentstring()
    end
  end,
})
