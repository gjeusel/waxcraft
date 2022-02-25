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
  pre_hook = function(ctx)
    if vim.bo.filetype == "vue" then
      require("ts_context_commentstring.internal").update_commentstring()
    end
    -- Only calculate commentstring for tsx filetypes
    if vim.bo.filetype == "typescriptreact" then
      local U = require("Comment.utils")

      -- Detemine whether to use linewise or blockwise commentstring
      local type = ctx.ctype == U.ctype.line and "__default" or "__multiline"

      -- Determine the location where to calculate commentstring from
      local location = nil
      if ctx.ctype == U.ctype.block then
        location = require("ts_context_commentstring.utils").get_cursor_location()
      elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
        location = require("ts_context_commentstring.utils").get_visual_start_location()
      end

      return require("ts_context_commentstring.internal").calculate_commentstring({
        key = type,
        location = location,
      })
    end
  end,
})
