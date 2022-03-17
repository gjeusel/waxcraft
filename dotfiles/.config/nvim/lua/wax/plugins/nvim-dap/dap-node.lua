local dap = require("dap")

-- https://github.com/mfussenegger/nvim-dap/wiki/Debug-Adapter-installation#javascript
dap.adapters.node2 = {
  type = "executable",
  command = "node",
  args = { os.getenv("HOME") .. "/src/vscode-node-debug2/out/src/nodeDebug.js" },
}

dap.adapters.chrome = {
  type = "executable",
  command = "node",
  args = { os.getenv("HOME") .. "/src/vscode-chrome-debug/out/src/chromeDebug.js" },
}

local base_cfg = {
  {
    type = "node2",
    name = "node attach",
    request = "attach",
    program = "${file}",
    cwd = vim.fn.getcwd(),
    sourceMaps = true,
    protocol = "inspector",
  },
  {
    type = "chrome",
    name = "chrome",
    request = "attach",
    program = "${file}",
    -- cwd = "${workspaceFolder}",
    -- protocol = "inspector",
    port = 9222,
    webRoot = "${workspaceFolder}",
    -- sourceMaps = true,
    sourceMapPathOverrides = {
      -- Sourcemap override for nextjs
      ["webpack://_N_E/./*"] = "${webRoot}/*",
      ["webpack:///./*"] = "${webRoot}/*",
    },
  },
  -- {
  --   -- For this to work you need to make sure the node process is started with the `--inspect` flag.
  --   name = "Attach to process",
  --   type = "node2",
  --   request = "attach",
  --   processId = require("dap.utils").pick_process,
  -- },
}

local vite_cfg = {
  {
    name = "Vitest Debug Current Test File",
    type = "node2",
    request = "launch",
    -- program = "${file}",
    program = "${workspaceFolder}/node_modules/vitest/vitest.mjs",
    args = { "run", "${relativeFile}" },
    -- args = { "--run", "--threads", "false" },
    cwd = vim.fn.getcwd(),
    autoAttachChildProcesses = true,
    skipFiles = { "<node_internals>/**", "**/node_modules/**" },
    smartStep = true,
    -- sourceMaps = true,
    protocol = "inspector",
    console = "integratedTerminal",
  },
}

dap.configurations.javascript = base_cfg
dap.configurations.javascriptreact = base_cfg

dap.configurations.typescript = vim.tbl_extend("keep", base_cfg, vite_cfg)
dap.configurations.typescriptreact = base_cfg

require("dap.ext.vscode").load_launchjs() -- load available debug config from .vscode/launch.json
