local has_dap, dap = pcall(require, "dap")
if not has_dap then
  return
end

dap.set_log_level("TRACE")
dap.defaults.fallback.terminal_win_cmd = "10vsplit new"

-- imports specific configurations for languages
require("wax.plugins.nvim-dap.dap-python")
require("wax.plugins.nvim-dap.dap-node")

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

map("<leader>dW", require("dap").step_back, "step_back")
map("<leader>dw", require("dap").step_over, "step_over")

map("<leader>ds", require("dap").step_into, "step_into")
map("<leader>dS", require("dap").step_out, "step_out")
-- map("<leader>ds", require("dap").up, "up_in_stack")
-- map("<leader>dS", require("dap").down, "down_in_stack")

map("<leader>dc", require("dap").continue, "continue")
map("<leader>df", require("dap").run_to_cursor, "run_to_cursor")

map("<leader>dd", require("dap").toggle_breakpoint, "toggle_breakpoint")

map("<leader>dr", require("dap").repl.toggle, "repl")
map("<leader>de", require("dapui").eval, "dapui_eval")

map("<leader>d2", require("dap").run_last, "run_last")

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
  -- You can change the order of elements in the sidebar
  sidebar = {
    elements = {
      -- Provide as ID strings or tables with "id" and "size" keys
      {
        id = "scopes",
        size = 0.75, -- Can be float or integer > 1
      },
      { id = "watches", size = 00.25 },
    },
    size = 50,
    position = "left", -- Can be "left" or "right"
  },

  tray = {
    elements = {},
    size = 15,
    position = "bottom", -- Can be "bottom" or "top"
  },
})

--   call Send_to_Tmux(s:pretty_command(a:cmd)."\n")
-- dap.defaults.fallback.external_terminal = {
--   command = '/usr/bin/alacritty';
--   args = {'-e'};
-- }
