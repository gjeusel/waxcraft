local signs = {
  -- { name = "DapStopped", text = "⋙", texthl = "DiagnosticWarn" },
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

local float_win_opts = { width = 80, height = 30, enter = true, position = "center" }

-- Taken from:
-- https://www.youtube.com/watch?v=Ul_WPhS2bis
--
-- https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/dap/core.lua
return {
  { -- mason.nvim integration
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "nvim-dap" },
    cmd = { "DapInstall", "DapUninstall" },
    opts = { handlers = {} },
  },
  -- { -- dap virtual text
  --   "theHamsta/nvim-dap-virtual-text",
  --   config = true,
  --   opts = {},
  -- },
  -- { -- fancy UI for the debugger
  --   "rcarriga/nvim-dap-ui",
  --   dependencies = { "nvim-neotest/nvim-nio" },
  --   opts = {
  --     controls = { enabled = false },
  --     icons = {
  --       collapsed = "⮕ ",
  --       current_frame = "⮕ ",
  --       expanded = "⤷",
  --     },
  --     layouts = {
  --       -- scopes & breakpoints & stacks are better done by fzf-lua, hence only repl
  --       {
  --         elements = { { id = "repl", size = 1 } },
  --         position = "bottom",
  --         size = 15,
  --       },
  --     },
  --     mappings = {
  --       edit = "e",
  --       expand = { "<CR>", "<2-LeftMouse>", "<Space>" },
  --       open = "o",
  --       remove = "dd",
  --       repl = "r",
  --       toggle = "t",
  --     },
  --   },
  -- },
  { -- nvim-dap
    "mfussenegger/nvim-dap",
    config = function()
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

      -- Customize windows
      repl.commands = vim.tbl_extend("force", repl.commands, {
        -- Add a new alias for the existing .exit command
        exit = { "exit", ".exit", ".bye" },
        -- Add your own commands; run `.echo hello world` to invoke
        -- this function with the text "hello world"
        custom_commands = {
          ["c"] = function() dap.continue() end,
          ["n"] = function() dap.step_over() end,
          ["s"] = function() dap.step_into() end,
        },
      })
    end,
    -- stylua: ignore
    keys = {
      -- { "<leader>fu", function() require("dapui").toggle({ }) end, desc = "[DAP] toggle UI" },
      -- { "<leader>fS", function() require("dapui").open({ reset = true }) end, desc="[DAP] reset UI split size"},
      -- { "<leader>fs", function() require("dapui").float_element("stacks", float_win_opts) end, desc="[DAP] UI open stack"},
      -- { "<leader>fv", function() require("dapui").float_element("scopes", float_win_opts) end, desc="[DAP] UI open variable scopes"},
      -- { "<leader>fb", function() require("dapui").float_element("breakpoints", float_win_opts) end, desc="[DAP] UI open breakpoitns"},
      -- { "<leader>ft", function() require("dapui").eval(nil, {context="repl", enter=true}) end, desc = "[DAP] UI eval", mode = {"n", "v"} },
      --
      { "<leader>fd", function() require("dap").toggle_breakpoint() end, desc = "[DAP] toggle breakpoint" },
      { "<leader>fo", function() require("dap").step_over() end, desc = "[DAP] step over" },
      { "<leader>fO", function() require("dap").step_out() end, desc = "[DAP] step over" },
      { "<leader>fi", function() require("dap").step_into() end, desc = "[DAP] step into" },
      { "<leader>ft", function() require("dap").hover() end, desc = "[DAP] hover"},
      { "<leader>fr", function() require("dap").repl.toggle() end, desc = "[DAP] open repl" },
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
            dap.repl.open()
          end

          dap.continue()
        end,
        desc = "[DAP] continue",
      },
    },
    dependencies = {
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
  },
}
