require("lspinstall/servers")["pyright"] = require("lspinstall/servers")["python"] -- pyright is named 'python' in lspinstall

local python_utils = require("wax.lsp.python-utils")

-- pyright_resolved_capabilities = {
--   call_hierarchy = true,
--   code_action = {
--     codeActionKinds = { "quickfix", "source.organizeImports" },
--     workDoneProgress = true,
--   },
--   code_lens = false,
--   code_lens_resolve = false,
--   completion = true,
--   declaration = false,
--   document_formatting = false,
--   document_highlight = { workDoneProgress = true },
--   document_range_formatting = false,
--   document_symbol = { workDoneProgress = true },
--   execute_command = true,
--   find_references = { workDoneProgress = true },
--   goto_definition = { workDoneProgress = true },
--   hover = { workDoneProgress = true },
--   implementation = false,
--   rename = true,
--   signature_help = true,
--   signature_help_trigger_characters = { "(", ",", ")" },
--   text_document_did_change = 2,
--   text_document_open_close = true,
--   text_document_save = true,
--   text_document_save_include_text = false,
--   text_document_will_save = false,
--   text_document_will_save_wait_until = false,
--   type_definition = false,
--   workspace_folder_properties = { changeNotifications = false, supported = false },
--   workspace_symbol = { workDoneProgress = true },
-- }

-- pylsp_resolved_capabilities = {
--   call_hierarchy = false,
--   code_action = true,
--   code_lens = true,
--   code_lens_resolve = false,
--   completion = true,
--   declaration = false,
--   document_formatting = true,
--   document_highlight = true,
--   document_range_formatting = true,
--   document_symbol = true,
--   execute_command = true,
--   find_references = true,
--   goto_definition = true,
--   hover = true,
--   implementation = false,
--   rename = true,
--   signature_help = true,
--   signature_help_trigger_characters = { "(", ",", "=" },
--   text_document_did_change = 2,
--   text_document_open_close = true,
--   text_document_save = { includeText = true },
--   text_document_save_include_text = true,
--   text_document_will_save = false,
--   text_document_will_save_wait_until = false,
--   type_definition = false,
--   workspace_folder_properties = { changeNotifications = true, supported = true },
--   workspace_symbol = false,
-- }

return {
  on_attach = function(client, _)
    -- disable capabilities that are better handled by pylsp
    client.resolved_capabilities.rename = false -- rope is ok
    client.resolved_capabilities.hover = false  -- pylsp includes also docstrings
    client.resolved_capabilities.signature_help = false  -- pyright typing of signature is weird
    client.resolved_capabilities.goto_definition = false -- pyright does not follow imports correctly
    client.resolved_capabilities.completion = false  -- pyright does not add parameters in signature
  end,
  settings = {
    python = {
      disableOrganizeImports = true,
      pythonPath = "python",
      analysis = {
        autoSearchPaths = true,
        -- useLibraryCodeForTypes = true,  -- pandas analysis is wrong
        useLibraryCodeForTypes = false,
        typeCheckingMode = "basic",
        diagnosticMode = "workspace",
      },
    },
  },
  on_new_config = function(config, new_workspace)
    local python_path = python_utils.on_new_workspace_python_path(new_workspace)

    if python_path == "python" then
      log.info(
        string.format(
          "LSP python - keeping previous python path '%s' for new_root_dir '%s'",
          config.pythonPath,
          new_workspace
        )
      )
      return config
    end

    log.info(
      string.format(
        "LSP python (pyright) - new path '%s' for new_root_dir '%s'",
        python_path,
        new_workspace
      )
    )
    config.pythonPath = python_path
    return config
  end,
}
