-- Taken from:
-- https://www.youtube.com/watch?v=Ul_WPhS2bis
--
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/dap/core.lua

local signs = {
  { name = "DapStopped", text = "→ ", texthl = "DiagnosticWarn" },
  { name = "DapBreakpoint", text = " ", texthl = "DiagnosticHint" },
  { name = "DapBreakpointRejected", text = "╳", texthl = "DiagnosticError" },
  { name = "DapBreakpointCondition", text = " ", texthl = "DiagnosticInfo" },
  { name = "DapLogPoint", text = " ", texthl = "DiagnosticInfo" },
}

local js_based_languages = {
  "typescript",
  "javascript",
  "typescriptreact",
  "javascriptreact",
  "vue",
}

local function config_dap()
  local dap = require("dap")
  local repl = require("dap.repl")

  for _, sign in ipairs(signs) do
    vim.fn.sign_define(sign.name, sign)
  end

  -- local dapui = require("dapui")
  -- dap.listeners.before.attach.dapui_config = function()
  --   dapui.open()
  -- end
  -- dap.listeners.before.launch.dapui_config = function()
  --   dapui.open()
  -- end
  -- dap.listeners.before.event_terminated.dapui_config = function()
  --   dapui.close()
  -- end
  -- dap.listeners.before.event_exited.dapui_config = function()
  --   dapui.close()
  -- end

  -- silence logs "could not read source map"
  dap.defaults.fallback.on_output = function(session, event)
    if
      event.category == "stdout"
      and not string.find(event.output, "Could not read source map for file")
    then
      repl.append(event.output, "$", { newline = false })
    end
  end

  for _, language in ipairs(js_based_languages) do
    dap.configurations[language] = {
      { -- Debug nodejs processes (make sure to add --inspect when you run the process)
        type = "pwa-node",
        request = "attach",
        name = "Attach",
        processId = require("dap.utils").pick_process,
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
      },
      { -- Debug single nodejs files
        type = "pwa-node",
        request = "launch",
        name = "Launch file",
        program = "${file}",
        cwd = vim.fn.getcwd(),
        sourceMaps = true,
      },
      { -- Debug web applications (client side)
        type = "pwa-chrome",
        request = "launch",
        name = "Launch & Debug Chrome",
        url = function()
          local co = coroutine.running()
          return coroutine.create(function()
            vim.ui.input({
              prompt = "Enter URL: ",
              default = "http://localhost:3033",
            }, function(url)
              if url == nil or url == "" then
                return
              else
                coroutine.resume(co, url)
              end
            end)
          end)
        end,
        webRoot = vim.fn.getcwd(),
        protocol = "inspector",
        sourceMaps = true,
        userDataDir = false,
      },
      { -- Divider for the launch.json derived configs
        name = "----- ↓ launch.json configs ↓ -----",
        type = "",
        request = "launch",
      },
    }
  end
end

---@param dir "next"|"prev"
local function gotoBreakpoint(dir)
  -- https://github.com/mfussenegger/nvim-dap/issues/792
  local breakpoints = require("dap.breakpoints").get()
  if #breakpoints == 0 then
    vim.notify("No breakpoints set", vim.log.levels.WARN)
    return
  end
  local points = {}
  for bufnr, buffer in pairs(breakpoints) do
    for _, point in ipairs(buffer) do
      table.insert(points, { bufnr = bufnr, line = point.line })
    end
  end

  local current = {
    bufnr = vim.api.nvim_get_current_buf(),
    line = vim.api.nvim_win_get_cursor(0)[1],
  }

  local nextPoint
  for i = 1, #points do
    local isAtBreakpointI = points[i].bufnr == current.bufnr and points[i].line == current.line
    if isAtBreakpointI then
      local nextIdx = dir == "next" and i + 1 or i - 1
      if nextIdx > #points then
        nextIdx = 1
      end
      if nextIdx == 0 then
        nextIdx = #points
      end
      nextPoint = points[nextIdx]
      break
    end
  end
  if not nextPoint then
    nextPoint = points[1]
  end

  vim.cmd(("buffer +%s %s"):format(nextPoint.line, nextPoint.bufnr))
end

local winopts_repl = { height = 15, width = 1 }

-- stylua: ignore
local keymaps = {
  { "<leader>fd", function() require("dap").toggle_breakpoint() end, desc = "[DAP] toggle breakpoint" },
  -- { "<leader>fo", function() require("dap").step_over() end, desc = "[DAP] step over" },
  -- { "<leader>fO", function() require("dap").step_out() end, desc = "[DAP] step over" },
  -- { "<leader>fi", function() require("dap").step_into() end, desc = "[DAP] step into" },
  { "<leader>ft", function() require("dap.ui.widgets").hover() end, desc = "[DAP] hover"},
  -- { "<leader>fr", function() require("dap").repl.toggle(winopts_repl) end, desc = "[DAP] open repl" },
  { "<leader>fr", function() require("dapui").toggle({}) end, desc = "[DAP] toggle UI" },
  { "<leader>fc",
    function()
      local dap = require("dap")
      if not dap.session() then
        local workspace = find_root_dir(vim.api.nvim_buf_get_name(0), { "package.json" })
        local vscode_launch_fpath = workspace .. "/.vscode/launch.json"
        if vim.fn.filereadable(vscode_launch_fpath) then
          local dap_vscode = require("dap.ext.vscode")
          dap_vscode.load_launchjs(vscode_launch_fpath, {
            ["pwa-node"] = js_based_languages,
            ["chrome"] = js_based_languages,
            ["pwa-chrome"] = js_based_languages,
          })
        end
        -- dap.repl.open(winopts_repl)
      end

      dap.continue()
    end,
    desc = "[DAP] continue",
  },
  {"[p", function () gotoBreakpoint("next") end, desc = '[DAP] go to next breakpoint'},
  {"]p", function () gotoBreakpoint("next") end, desc = '[DAP] go to next breakpoint'},
}

return {
  "mfussenegger/nvim-dap",
  lazy = false,
  config = config_dap,
  keys = keymaps,
  dependencies = {
    { -- fancy UI for the debugger
      "rcarriga/nvim-dap-ui",
      dependencies = { "nvim-neotest/nvim-nio" },
      opts = {
        controls = { enabled = false },
        icons = {
          collapsed = "⮕ ",
          current_frame = "⮕ ",
          expanded = "⤷",
        },
        layouts = {
          -- scopes & breakpoints & stacks are better done by fzf-lua, hence only repl
          {
            elements = { { id = "repl", size = 1 } },
            position = "bottom",
            size = 15,
          },
        },
        mappings = {
          edit = "e",
          expand = { "<CR>", "<2-LeftMouse>", "<Space>" },
          open = "o",
          remove = "dd",
          repl = "r",
          toggle = "t",
        },
      },
    },
    { -- mason.nvim integration
      "jay-babu/mason-nvim-dap.nvim",
      dependencies = { "nvim-dap" },
      cmd = { "DapInstall", "DapUninstall" },
      opts = { handlers = {} },
    },
    { -- vscode-js-debug adapter
      "microsoft/vscode-js-debug",
      -- After install, build it and rename the dist directory to out
      build = "npm install --legacy-peer-deps --no-save && npx gulp vsDebugServerBundle && rm -rf out && mv dist out",
      version = "1.*",
    },
    { -- nvim dap vscode js
      "mxsdev/nvim-dap-vscode-js",
      config = function()
        ---@diagnostic disable-next-line: missing-fields
        require("dap-vscode-js").setup({
          -- Path of node executable. Defaults to $NODE_PATH, and then "node"
          -- node_path = "node",

          -- Path to vscode-js-debug installation.
          debugger_path = vim.fn.resolve(vim.fn.stdpath("data") .. "/lazy/vscode-js-debug"),

          -- Command to use to launch the debug server. Takes precedence over "node_path" and "debugger_path"
          -- debugger_cmd = { "js-debug-adapter" },

          -- which adapters to register in nvim-dap
          adapters = {
            "chrome",
            "pwa-node",
            "pwa-chrome",
            "pwa-msedge",
            "pwa-extensionHost",
            "node-terminal",
          },

          -- Path for file logging
          log_file_path = vim.fn.stdpath("cache") .. "/dap_vscode_js.log",
          log_file_level = false,
          log_console_level = false,
          -- log_file_level = vim.log.levels.DEBUG,
          -- log_console_level = vim.log.levels.DEBUG,
        })
      end,
    },
    { -- lua json parser
      "Joakker/lua-json5",
      build = "./install.sh",
    },
  },
}
