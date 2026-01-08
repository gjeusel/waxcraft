-- Taken from:
-- https://www.youtube.com/watch?v=Ul_WPhS2bis
--
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/dap/core.lua

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
  --
  { "<leader>fr", "<cmd>DapViewToggle<cr>", desc = "[DAP] toggle view" },
  -- { "<leader>dw", "<cmd>DapViewWatch<cr>", desc = "[DAP] watch expr", mode = { "n", "v" } },
  { "<leader>fj", "<cmd>DapViewJump repl<cr>", desc = "[DAP] jump to repl" },
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

    -- -- Enable verbose logging (check ~/.cache/nvim/dap.log)
    -- dap.set_log_level("TRACE")

    -- Prevent "winfixbuf" errors when jumping to source from nvim-dap-view windows
    dap.defaults.fallback.switchbuf = "usevisible,usetab,newtab"

    -- Custom REPL commands (like pdbrc aliases)
    -- Helper to create a command that evaluates a Python template
    local function py_cmd(template)
      return function(args)
        local session = dap.session()
        if session then
          local code = template:format(args, args) -- double for sql which uses %s twice
          session:evaluate(code, function(err, resp)
            if err then
              repl.append("Error: " .. (err.message or vim.inspect(err)), "$")
            elseif resp and resp.result then
              repl.append(resp.result, "$")
            end
          end)
        else
          repl.append("No active debug session", "$")
        end
      end
    end

    repl.commands.custom_commands = vim.tbl_extend("force", repl.commands.custom_commands or {}, {
      [".p"] = py_cmd([[print(%s)]]),
      [".pp"] = py_cmd([[from pathlib import Path;from rich.console import Console;from rich.theme import Theme;Console(theme=Theme.read(Path("~/.config/rich/rich.ini").expanduser().as_posix())).print(%s)]]),
      [".pi"] = py_cmd([[from pathlib import Path;from rich.console import Console;from rich.theme import Theme;from rich import inspect;inspect(%s, console=Console(theme=Theme.read(Path("~/.config/rich/rich.ini").expanduser().as_posix())))]]),
      [".piv"] = py_cmd([[from pathlib import Path;from rich.console import Console;from rich.theme import Theme;from rich import inspect;inspect(%s, private=True, methods=True, console=Console(theme=Theme.read(Path("~/.config/rich/rich.ini").expanduser().as_posix())))]]),
      [".dpp"] = py_cmd([[__import__("devtools").debug(%s)]]),
      [".t"] = py_cmd([[type(%s)]]),
      [".sql"] = py_cmd([[print(__import__("sqlparse").format(str(getattr(%s, "statement", %s).compile(dialect=__import__("sqlalchemy").dialects.postgresql.dialect(), compile_kwargs={"literal_binds": True})), reindent=True, keyword_case="upper"))]]),
    })

    -- silence logs "could not read source map"
    dap.defaults.fallback.on_output = function(_, event)
      if
        event.category == "stdout"
        and not string.find(event.output, "Could not read source map for file")
      then
        repl.append(event.output, "$", { newline = false })
      end
    end

    -- REPL keymaps
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "dap-repl",
      callback = function()
        vim.keymap.set("i", "<C-w>", "<C-S-w>", { buffer = true })

        vim.keymap.set("i", "<C-p>", function()
          require("dap.repl").on_up()
        end, { buffer = true })
        vim.keymap.set("i", "<C-n>", function()
          require("dap.repl").on_down()
        end, { buffer = true })

        vim.keymap.set("i", "<C-a>", "<Home>", { buffer = true })
        vim.keymap.set("i", "<C-e>", "<End>", { buffer = true })
      end,
    })
  end,
  keys = keymaps,
  dependencies = {
    {
      "igorlfs/nvim-dap-view",
      opts = {
        winbar = {
          show = true,
          sections = {
            "repl",
            "scopes",
            "threads",
            "watches",
            "exceptions",
            "breakpoints",
            "console",
          },
          default_section = "repl",
        },
        windows = {
          size = 0.5,
          position = "right",
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

        local python_customs = {
          -- { -- Divider for the custom configs
          --   name = "----- ↓ custom configs ↓ -----",
          --   type = "",
          --   request = "launch",
          -- },
          {
            type = "python",
            request = "launch",
            justMyCode = true,
            subProcess = true,
            cwd = function()
              return find_root_package(vim.api.nvim_buf_get_name(0)) or vim.fn.getcwd()
            end,
            name = "Dagster Dev Server",
            module = "dagster",
            args = { "dev", "-p", "3001", "--log-format", "rich" },

            --
            -- name = "Dagster Dev Server (tmux)",
            -- connect = { host = "127.0.0.1", port = 5678 },
            -- request = "attach",
            -- preLaunchTask = function()
            --   local tmux = require("wax.tmux")
            --   local cwd = find_root_package(vim.api.nvim_buf_get_name(0)) or vim.fn.getcwd()
            --   local cmd = ("cd %s && python -m debugpy --listen 5678 --configure-subProcess true -m dagster dev -p 3001 --log-format rich"):format(cwd)
            --   tmux.run_in_pane(cmd, { interrupt_before = true, clear_before = true })
            --   -- Give debugpy time to start listening
            --   vim.wait(2000)
            -- end,
          },
        }

        -- vim.list_extend(dap.configurations.python, python_customs)
        dap.configurations.python = python_customs

        vim.list_extend(dap.configurations.python, { separator_launchjson })
      end,
    },
  },
}
