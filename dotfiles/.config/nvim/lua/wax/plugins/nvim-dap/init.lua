local has_dap, dap = pcall(require, "dap")
if not has_dap then
  return
end

dap.set_log_level(waxopts.loglevel)
dap.defaults.fallback.terminal_win_cmd = "10split new"

-- imports specific configurations for languages
require("wax.plugins.nvim-dap.dap-python")
dap_node = require("wax.plugins.nvim-dap.dap-node")

local function dap_run_or_continue()
  if dap.session() then
    return dap.continue()
  end

  dap_node.run_vitest_in_tmux(vim.fn.expand("%:p"), nil)
end

vim.fn.sign_define(
  "DapBreakpoint",
  { text = "ß", texthl = "GruvboxBlue", linehl = "", numhl = "" }
)
vim.fn.sign_define(
  "DapBreakpointRejected",
  { text = "ß", texthl = "GruvboxRed", linehl = "", numhl = "" }
)
vim.fn.sign_define("DapStopped", { text = "→", texthl = "GruvboxGreen", linehl = "", numhl = "" })

require("nvim-dap-virtual-text").setup({
  enabled = true,
  show_stop_reason = true,
  commented = false, -- prefix virtual text with comment string
  enabled_commands = false, -- add commands DapVirtualTextToggle, DapVirtualTextForceRefresh, ...
  -- -- highlight changed values with NvimDapVirtualTextChanged, else always NvimDapVirtualText
  -- highlight_changed_variables = true,
  -- highlight_new_as_changed = true,
  -- -- experimental features:
  -- virt_text_pos = "eol", -- position of virtual text, see `:h nvim_buf_set_extmark()`
  -- all_frames = false, -- show virtual text for all stack frames not only current. Only works for debugpy on my machine.
})

local map = function(lhs, rhs, desc)
  if desc then
    desc = "[DAP] " .. desc
  end

  vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
end

-- map("<leader>dW", require("dap").step_back, "step_back")
-- map("<leader>dw", require("dap").step_over, "step_over")

-- map("<leader>ds", require("dap").step_into, "step_into")
-- map("<leader>dS", require("dap").step_out, "step_out")
-- -- map("<leader>ds", require("dap").up, "up_in_stack")
-- -- map("<leader>dS", require("dap").down, "down_in_stack")

-- -- map("<leader>dc", require("dap").continue, "continue")
-- map("<leader>dc", dap_run_or_continue, "continue")
-- map("<leader>df", require("dap").run_to_cursor, "run_to_cursor")

-- map("<leader>dd", require("dap").toggle_breakpoint, "toggle_breakpoint")

-- map("<leader>dr", require("dap").repl.toggle, "repl")
-- map("<leader>de", require("dapui").eval, "dapui_eval")
-- map("<leader>dD", require("dapui").toggle, "dapui_eval")

-- map("<leader>d2", require("dap").run_last, "run_last")

-- map("<leader>dB", function()
--   require("dap").set_breakpoint(vim.fn.input("[DAP] Condition > "))
-- end)
-- map("<leader>dE", function()
--   require("dapui").eval(vim.fn.input("[DAP] Expression > "))
-- end)

-- You can set trigger characters OR it will default to '.'
-- You can also trigger with the omnifunc, <c-x><c-o>
vim.cmd([[
augroup DapRepl
  au!
  au FileType dap-repl lua require('dap.ext.autocompl').attach()
augroup END
]])

require("dapui").setup({
  layouts = {
    {
      elements = {
        "scopes",
        "breakpoints",
        "stacks",
        "watches",
      },
      size = 40,
      position = "left",
    },
    {
      elements = {
        "repl",
        "console",
      },
      size = 10,
      position = "bottom",
    },
  },
})
