local langutils = require("wax.langutils")
local tmux = require("wax.tmux")
local dap = require("dap")

-- Some Links:
-- specs for node: https://code.visualstudio.com/docs/nodejs/nodejs-debugging
-- rockerBOO setup: https://github.com/rockerBOO/dotfiles/blob/current/config/nvim/lua/plugin/dap.lua
-- awwalker setup: https://github.com/awwalker/dotfiles/blob/master/.config/nvim/lua/plugins/debuggers/typescript.lua
-- multi session adapters: https://github.com/mfussenegger/nvim-dap/issues/136

-- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#javascript
dap.adapters.node2 = {
  -- https://github.com/microsoft/vscode-node-debug2
  type = "executable",
  command = langutils.node.path,
  args = { os.getenv("HOME") .. "/src/vscode-node-debug2/out/src/nodeDebug.js" },
}

-- dap.adapters.chrome = {
--   type = "executable",
--   command = "node",
--   args = { os.getenv("HOME") .. "/src/vscode-chrome-debug/out/src/chromeDebug.js" },
-- }

local root_dir = langutils.node.find_root_dir(vim.fn.getcwd()) or ""

local node2_attach = {
  type = "node2",
  request = "attach",
  name = "node-attach",
  stopOnEntry = false,
  cwd = root_dir,
}

local vitest_node2_launch_file = {
  name = "vitest-launch-file",
  type = "node2",
  request = "launch",
  --
  cwd = root_dir,
  program = root_dir .. "/node_modules/vitest/vitest.mjs",
  args = { "run", "--threads", false, "--update", "--run", "${relativeFile}" },
  --
  smartStep = true,
  stopOnEntry = false,
  autoAttachChildProcesses = true,
  sourceMaps = true,
  skipFiles = { "<node_internals>/**", "**/node_modules/**" },
  protocol = "inspector",
  console = "integratedTerminal",
  runtimeExecutable = langutils.node.path,
  runtimeArgs = { "--trace-warnings" },
}

local function get_vitest_launch_with_pattern(pattern)
  return vim.tbl_extend("force", vitest_node2_launch_file, {
    name = "vitest-launch-file-with-pattern",
    args = vim.tbl_extend("keep", vitest_node2_launch_file.args, { "--testNamePattern", pattern }),
  })
end

local function run_vitest_in_tmux(filepath, pattern)
  local workspace = langutils.node.find_root_dir(vim.fn.getcwd())

  local node_run_cmd = {
    "node",
    "--enable-source-maps",
    "--inspect-brk",
    workspace .. "/node_modules/vitest/vitest.mjs",
    "run",
    -- "--threads",
    -- "false",
    "--run",
    -- "--update",
    "--globals",
    "--dom",
  }

  if filepath then
    vim.list_extend(node_run_cmd, { filepath })
  end
  if pattern then
    vim.list_extend(node_run_cmd, { "--testNamePattern", pattern })
  end

  local is_running = tmux.run_in_pane(node_run_cmd)
  if not is_running then
    return
  end

  local dap_run_opts = {
    type = "node2",
    request = "attach",
    name = "vitest-attach",
    stopOnEntry = false,
    cwd = root_dir,
  }
  dap.run(dap_run_opts)
end

dap.configurations.javascript = { vitest_node2_launch_file }
-- dap.configurations.javascriptreact = {node2_attach}
dap.configurations.typescript = { vitest_node2_launch_file }
-- dap.configurations.typescriptreact = {node2_attach}

-- require("dap.ext.vscode").load_launchjs(
--   -- load available debug config from .vscode/launch.json
--   nil,
--   { ["pwa-node"] = { "typescript", "javascript" } }
-- )

return {
  run_vitest_in_tmux = run_vitest_in_tmux,
}
