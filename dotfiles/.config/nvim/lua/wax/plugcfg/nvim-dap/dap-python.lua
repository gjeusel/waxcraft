-- local dap = require("dap")

-- dap.adapters.python = {
--   type = "executable",
--   -- command = os.getenv("HOME") .. "/.virtualenvs/tools/bin/python",
--   command = "python",
--   args = { "-m", "debugpy.adapter" },
-- }

-- dap.configurations.python = {
--   {
--     type = "python",
--     request = "launch",
--     name = "Build api",
--     -- program = "${file}",
--     args = { "--target", "api" },
--     console = "integratedTerminal",
--     -- console = "externalTerminal",
--     module = "pytest"
--   },
-- }

local dap_python = require("dap-python")

dap_python.setup("python", {
  console = "integratedTerminal",
  include_configs = true,
})

dap_python.test_runner = "pytest"

-- dap_python.test_runner = "pytest"
