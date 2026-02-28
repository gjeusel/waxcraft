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

local separator_commons = { -- Divider for the common configs
  name = "----- ↓ commons ↓ -----",
  type = "",
  request = "launch",
}

local dap_hover_view = nil

local function dap_hover_toggle()
  if dap_hover_view then
    dap_hover_view.close()
    dap_hover_view = nil
    return
  end
  dap_hover_view = require("dap.ui.widgets").hover()
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = dap_hover_view.buf,
    once = true,
    callback = function()
      if dap_hover_view then
        dap_hover_view.close()
        dap_hover_view = nil
      end
    end,
  })
end

local function ensure_dap_view_open()
  local state = require("dap-view.state")
  if not (state.winnr and vim.api.nvim_win_is_valid(state.winnr)) then
    vim.cmd("DapViewOpen")
  end
end

local keymaps = {
  -- stylua: ignore start

  -- stepping
  { "<leader>fo", function() require("dap").step_over() end, desc = "[DAP] step over" },
  { "<leader>fn", function() require("dap").step_into() end, desc = "[DAP] step into" },
  { "<leader>fO", function() require("dap").step_out() end, desc = "[DAP] step out" },
  { "<leader>ft", function() require("dap").run_to_cursor() end, desc = "[DAP] run to cursor" },

  -- session lifecycle
  { "<leader>fc", function() require("dap").continue() end, desc = "[DAP] continue" },
  { "<leader>fq", function() require("dap").terminate(); vim.cmd("DapViewClose") end, desc = "[DAP] terminate" },

  -- breakpoints
  { "<leader>fd", function() require("dap").toggle_breakpoint() end, desc = "[DAP] toggle breakpoint" },
  { "<leader>fD", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "[DAP] conditional breakpoint" },
  { "[p", function() gotoBreakpoint("prev") end, desc = "[DAP] go to prev breakpoint" },
  { "]p", function() gotoBreakpoint("next") end, desc = "[DAP] go to next breakpoint" },

  -- ui & eval
  { "<leader>fv", "<cmd>DapViewToggle<cr>", desc = "[DAP] toggle view" },
  { "<leader>fr", function()
    ensure_dap_view_open()
    vim.cmd("DapViewJump repl")
    vim.schedule(function() vim.cmd("startinsert") end)
  end, desc = "[DAP] jump to repl" },
  { "<leader>fs", function()
    ensure_dap_view_open()
    vim.cmd("DapViewJump scopes")
  end, desc = "[DAP] jump to scopes" },
  { "<leader>fu", dap_hover_toggle, desc = "[DAP] eval under cursor", mode = { "n", "v" } },

  -- stylua: ignore end
}

return {
  "mfussenegger/nvim-dap",
  lazy = false,
  config = function()
    local signs = {
      { name = "DapStopped", text = "▶ ", texthl = "DiagnosticWarn" },
      { name = "DapBreakpoint", text = "● ", texthl = "DiagnosticHint" },
      { name = "DapBreakpointRejected", text = "○ ", texthl = "DiagnosticError" },
      { name = "DapBreakpointCondition", text = "◆ ", texthl = "DiagnosticInfo" },
      { name = "DapLogPoint", text = "◈ ", texthl = "DiagnosticInfo" },
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

    -- Override launch.json provider to use find_root_dir instead of cwd
    -- Replace built-in launch.json provider with one that uses find_root_dir.
    -- Key "dap.a.launch.json" sorts before "dap.global" so project configs appear first.
    dap.providers.configs["dap.launch.json"] = function()
      return {}
    end
    dap.providers.configs["dap.a.launch.json"] = function()
      local root = find_root_dir(vim.api.nvim_buf_get_name(0))
      if not root then
        return {}
      end
      local launch_path = root .. "/.vscode/launch.json"
      local ok, configs = pcall(require("dap.ext.vscode").getconfigs, launch_path)
      if not ok then
        return {}
      end
      return configs
    end

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
      [".pp"] = py_cmd(
        [[from pathlib import Path;from rich.console import Console;from rich.theme import Theme;Console(theme=Theme.read(Path("~/.config/rich/rich.ini").expanduser().as_posix())).print(%s)]]
      ),
      [".pi"] = py_cmd(
        [[from pathlib import Path;from rich.console import Console;from rich.theme import Theme;from rich import inspect;inspect(%s, console=Console(theme=Theme.read(Path("~/.config/rich/rich.ini").expanduser().as_posix())))]]
      ),
      [".piv"] = py_cmd(
        [[from pathlib import Path;from rich.console import Console;from rich.theme import Theme;from rich import inspect;inspect(%s, private=True, methods=True, console=Console(theme=Theme.read(Path("~/.config/rich/rich.ini").expanduser().as_posix())))]]
      ),
      [".dpp"] = py_cmd([[__import__("devtools").debug(%s)]]),
      [".t"] = py_cmd([[type(%s)]]),
      [".sql"] = py_cmd(
        [[print(__import__("sqlparse").format(str(getattr(%s, "statement", %s).compile(dialect=__import__("sqlalchemy").dialects.postgresql.dialect(), compile_kwargs={"literal_binds": True})), reindent=True, keyword_case="upper"))]]
      ),
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
      "Joakker/lua-json5", -- lua json parser
      build = "./install.sh",
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
            separator_commons,
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
      end,
    },
    {
      -- Custom Python DAP: launches debugpy in a tmux pane so the command output is visible,
      -- then connects nvim-dap via TCP.
      "wax-dap-python",
      virtual = true,
      config = function()
        local dap = require("dap")
        local python_utils = require("wax.lsp.python-utils")
        local tmux = require("wax.tmux")

        local DEBUGPY_PORT_MIN = 50000

        --- Discover running debugpy listeners via lsof.
        --- Returns list of { pid = string, port = number, cmd = string }
        local function get_debugpy_ports()
          local result = vim
            .system({ "lsof", "-iTCP", "-sTCP:LISTEN", "-P", "-n", "-F", "pcn" }, { text = true })
            :wait()
          if result.code ~= 0 or not result.stdout then
            return {}
          end

          -- Parse lsof -F output: p<pid>\nc<cmd>\nn<name> (repeated per entry)
          local entries = {}
          local cur = {}
          for line in result.stdout:gmatch("[^\n]+") do
            local tag, val = line:sub(1, 1), line:sub(2)
            if tag == "p" then
              if cur.pid then
                table.insert(entries, cur)
              end
              cur = { pid = val }
            elseif tag == "c" then
              cur.cmd = val
            elseif tag == "n" then
              local port = val:match(":(%d+)$")
              if port then
                cur.port = tonumber(port)
              end
            end
          end
          if cur.pid then
            table.insert(entries, cur)
          end

          -- Filter to debugpy processes: Python command on high ports with debugpy in cmdline
          return vim.tbl_filter(function(e)
            if
              not (e.port and e.port >= DEBUGPY_PORT_MIN and e.cmd and e.cmd:lower():find("python"))
            then
              return false
            end
            local ps = vim.system({ "ps", "-p", e.pid, "-o", "command=" }, { text = true }):wait()
            if ps.code == 0 and ps.stdout then
              e.cmdline = vim.trim(ps.stdout)
              return e.cmdline:find("debugpy") ~= nil
            end
            return false
          end, entries)
        end

        local function get_free_port()
          local tcp = vim.uv.new_tcp()
          tcp:bind("127.0.0.1", 0)
          local port = tcp:getsockname().port
          tcp:close()
          -- Ensure port is in the debugpy range (>=50000)
          if port < DEBUGPY_PORT_MIN then
            return get_free_port()
          end
          return port
        end

        --- Run a command in tmux, then call on_sent after the command is dispatched.
        ---@param cmd string
        ---@param on_sent fun()
        local function run_in_tmux_then(cmd, on_sent)
          local send_opts = { interrupt_before = true, clear_before = true }

          if tmux.target_pane ~= nil and #tmux.previous_panes == #tmux.get_panes() then
            tmux.send(tmux.target_pane, cmd, send_opts)
            on_sent()
            return
          end

          tmux.select_target_pane(function(selected_pane)
            tmux.send(selected_pane, cmd, send_opts)
            on_sent()
          end)
        end

        dap.adapters.python = function(callback, config)
          if config.request == "attach" then
            callback({
              type = "server",
              host = config.connect and config.connect.host or "127.0.0.1",
              port = config.connect and config.connect.port or 5678,
              options = { source_filetype = "python" },
            })
            return
          end

          -- "launch" request: run debugpy in a tmux pane, then connect via TCP
          local python_path = python_utils.get_python_path()
          local port = get_free_port()

          local cmd_parts =
            { python_path, "-m", "debugpy", "--listen", tostring(port), "--wait-for-client" }

          if config.subProcess then
            table.insert(cmd_parts, "--configure-subProcess")
            table.insert(cmd_parts, "true")
          end

          if config.module then
            table.insert(cmd_parts, "-m")
            table.insert(cmd_parts, config.module)
          elseif config.program then
            local program = config.program
            if type(program) == "function" then
              program = program()
            end
            program = program:gsub("%${file}", vim.fn.expand("%:p"))
            table.insert(cmd_parts, program)
          end

          if config.args then
            for _, arg in ipairs(config.args) do
              table.insert(cmd_parts, arg)
            end
          end

          local cwd = find_root_package(vim.api.nvim_buf_get_name(0)) or vim.fn.getcwd()

          local full_cmd = "cd " .. cwd .. " && " .. table.concat(cmd_parts, " ")

          run_in_tmux_then(full_cmd, function()
            vim.defer_fn(function()
              callback({
                type = "server",
                host = "127.0.0.1",
                port = port,
                enrich_config = function(final_config, on_config)
                  final_config.request = "attach"
                  if not final_config.pythonPath then
                    final_config.pythonPath = python_path
                  end
                  on_config(final_config)
                end,
                options = { source_filetype = "python" },
              })
            end, 2000)
          end)
        end

        -- Default Python configurations
        -- launch.json configs appear first (via "dap.a.launch.json" provider),
        -- then these common configs after the separator
        dap.configurations.python = {
          separator_commons,
          {
            type = "python",
            request = "launch",
            name = "Launch file",
            program = "${file}",
            justMyCode = true,
          },
          {
            type = "python",
            request = "attach",
            name = "Attach (connect)",
            connect = function()
              local ports = get_debugpy_ports()
              local host = "127.0.0.1"

              if #ports == 0 then
                -- Fallback to manual input
                return {
                  host = vim.fn.input("Host [127.0.0.1]: ", "127.0.0.1"),
                  port = tonumber(vim.fn.input("Port [5678]: ", "5678")),
                }
              elseif #ports == 1 then
                vim.notify(
                  ("Attaching to debugpy on port %d (pid %s)"):format(ports[1].port, ports[1].pid)
                )
                return { host = host, port = ports[1].port }
              else
                -- Multiple: use coroutine + vim.ui.select
                local co = coroutine.running()
                vim.ui.select(ports, {
                  prompt = "Select debugpy process> ",
                  format_item = function(e)
                    return ("port %d | pid %s | %s"):format(e.port, e.pid, e.cmdline or e.cmd)
                  end,
                }, function(choice)
                  if choice then
                    coroutine.resume(co, { host = host, port = choice.port })
                  else
                    coroutine.resume(co, nil)
                  end
                end)
                return coroutine.yield()
              end
            end,
          },
        }
      end,
    },
  },
}
