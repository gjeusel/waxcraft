-- Taken from:
-- https://www.youtube.com/watch?v=Ul_WPhS2bis
--
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/dap/core.lua

local tmux = require("wax.tmux")

local js_based_languages =
  { "typescript", "javascript", "typescriptreact", "javascriptreact", "vue" }

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

local function loadVSCodeLaunch()
  local workspace = find_root_dir(vim.api.nvim_buf_get_name(0))
  if workspace == nil then
    return
  end

  local vscode_launch_fpath = workspace .. "/.vscode/launch.json"
  if not vim.fn.filereadable(vscode_launch_fpath) then
    return
  end

  local dap_vscode = require("dap.ext.vscode")

  if vim.fn.filereadable(workspace .. "/package.json") then
    dap_vscode.load_launchjs(vscode_launch_fpath, {
      ["pwa-node"] = js_based_languages,
      ["chrome"] = js_based_languages,
      ["pwa-chrome"] = js_based_languages,
    })
  end
  if vim.fn.filereadable(workspace .. "/pyproject.toml") then
    dap_vscode.load_launchjs(vscode_launch_fpath, { python = { "python" } })
  end
end

local separator_launchjson = { -- Divider for the launch.json derived configs
  name = "----- ↓ launch.json configs ↓ -----",
  type = "",
  request = "launch",
}

local keymaps = {
  -- stylua: ignore start
  { "<leader>fd", function() require("dap").toggle_breakpoint() end, desc = "[DAP] toggle breakpoint" },
  -- { "<leader>fo", function() require("dap").step_over() end, desc = "[DAP] step over" },
  -- { "<leader>fO", function() require("dap").step_out() end, desc = "[DAP] step over" },
  -- { "<leader>fi", function() require("dap").step_into() end, desc = "[DAP] step into" },
  { "<leader>ft", function() require("dap.ui.widgets").hover() end, desc = "[DAP] hover"},
  { "<leader>fr", function() require("dapui").toggle({}) end, desc = "[DAP] toggle UI" },
  {"[p", function () gotoBreakpoint("prev") end, desc = '[DAP] go to prev breakpoint'},
  {"]p", function () gotoBreakpoint("next") end, desc = '[DAP] go to next breakpoint'},
  -- stylua: ignore end
  {
    "<leader>fc",
    function()
      local dap = require("dap")
      if not dap.session() then
        loadVSCodeLaunch()
      end

      dap.continue()
    end,
    desc = "[DAP] continue",
  },
}

return {
  "mfussenegger/nvim-dap",
  lazy = false,
  config = function()
    local signs = {
      { name = "DapStopped", text = "→ ", texthl = "DiagnosticWarn" },
      { name = "DapBreakpoint", text = " ", texthl = "DiagnosticHint" },
      { name = "DapBreakpointRejected", text = "╳", texthl = "DiagnosticError" },
      { name = "DapBreakpointCondition", text = " ", texthl = "DiagnosticInfo" },
      { name = "DapLogPoint", text = " ", texthl = "DiagnosticInfo" },
    }

    for _, sign in ipairs(signs) do
      vim.fn.sign_define(sign.name, sign)
    end

    local dap = require("dap")
    local repl = require("dap.repl")

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
    dap.defaults.fallback.on_output = function(_, event)
      if
        event.category == "stdout"
        and not string.find(event.output, "Could not read source map for file")
      then
        repl.append(event.output, "$", { newline = false })
      end
    end
  end,
  keys = keymaps,
  dependencies = {
    {
      "rcarriga/nvim-dap-ui", -- fancy UI for the debugger
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
            elements = {
              { id = "scopes", size = 1 },
              -- { id = "stacks", size = 0.25 },
            },
            position = "bottom",
            size = 5,
          },
          {
            elements = { { id = "repl", size = 1 } },
            position = "bottom",
            size = 10,
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
    {
      "jay-babu/mason-nvim-dap.nvim", -- mason.nvim integration
      cmd = { "DapInstall", "DapUninstall" },
      opts = { handlers = {} },
    },
    {
      "microsoft/vscode-js-debug", -- vscode-js-debug adapter
      -- After install, build it and rename the dist directory to out
      build = "npm install --legacy-peer-deps --no-save && npx gulp vsDebugServerBundle && rm -rf out && mv dist out",
      version = "1.*",
    },
    {
      "mxsdev/nvim-dap-vscode-js", -- nvim dap vscode js
      config = function()
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

        local dap = require("dap")

        -- Configure JS
        for _, language in ipairs(js_based_languages) do
          vim.list_extend(dap.configurations[language] or {}, {
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
          })
        end

        -- add separator
        for _, language in ipairs(js_based_languages) do
          vim.list_extend(dap.configurations[language] or {}, separator_launchjson)
        end
      end,
    },
    {
      "Joakker/lua-json5", -- lua json parser
      build = "./install.sh",
    },
    {
      "mfussenegger/nvim-dap-python",
      config = function()
        -- TODO: setup with a more precise python path / or uv ?
        require("dap-python").setup("python")
        -- require("dap-python").setup("uv")

        local dap = require("dap")

        vim.list_extend(dap.configurations.python, {
          { -- Divider for the custom configs
            name = "----- ↓ custom configs ↓ -----",
            type = "",
            request = "launch",
          },
          {
            type = "python",
            request = "launch",
            name = "Dagster Dev Server",
            program = function()
              local cmd = "dagster dev -p 3001 --log-format rich"
              tmux.run_in_pane(cmd, { interrupt_before = true, clear_before = true })
              return vim.fn.getcwd() .. "/__dummy__.py" -- Return dummy program path (required by DAP)
            end,
            justMyCode = false,
            cwd = "${workspaceFolder}",
          },
        })
        vim.list_extend(dap.configurations.python, { separator_launchjson })
      end,
    },
  },
}
