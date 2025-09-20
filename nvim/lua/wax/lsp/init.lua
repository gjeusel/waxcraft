local ms = require("vim.lsp.protocol").Methods

-- Set log level for LSP
vim.lsp.log.set_level(waxopts.loglevel)

local function goto_alias_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  local timeout = 1000

  for _, client in ipairs(clients) do
    if client:supports_method(ms.textDocument_definition) then
      local resp = client:request_sync(
        ms.textDocument_definition,
        vim.lsp.util.make_position_params(0, "utf-8"),
        timeout,
        bufnr
      )
      if resp ~= nil and resp.result and #resp.result > 0 then
        local location = resp.result[1]
        local uri = location.uri or location.targetUri

        -- TODO: make the or statement inside the regex
        local is_gotoalias_case = string.match(uri, ".*imports.d.ts")
          or string.match(uri, ".*components.d.ts")

        if not is_gotoalias_case then
          vim.lsp.util.show_document(location, "utf-8")
          return
        end

        -- Special case of jump into redirection file: "imports.d.ts"
        -- Doing the equivalent of https://github.com/antfu/vscode-goto-alias
        local tmp_buf = vim.fn.bufadd(uri:sub(8))
        vim.fn.bufload(tmp_buf)

        local line_num = location["targetRange"]["end"]["line"]
        local lines = vim.api.nvim_buf_get_lines(tmp_buf, line_num, line_num + 1, false)
        local line_length = #lines[1] - 1

        local nested_position = { line = line_num, character = line_length - 1 }
        local nested_resp = client.request_sync(ms.textDocument_definition, {
          position = nested_position,
          textDocument = { uri = uri },
        }, timeout * 5, bufnr)

        if nested_resp and nested_resp.result then
          local nested_location = nested_resp.result[1]
          vim.lsp.util.show_document(nested_location, "utf-8")
          -- vim.api.nvim_buf_delete(tmp_buf, { force = true })
        else
          log.warn("Could not jump to alias with nested_position=", nested_position)
          vim.lsp.util.show_document(location, "utf-8")
        end
      end
    end
  end
end

local function goto_first_definition()
  if vim.tbl_contains({ "vue", "typescript" }, vim.bo.filetype) then
    goto_alias_definition()
  else
    vim.lsp.buf.definition({
      on_list = function(options)
        vim.fn.setqflist({}, " ", options)
        vim.api.nvim_command("silent! cfirst!")
      end,
    })
  end
end

-- mappings diagnostics
local goto_win_opts = {
  float = {
    format = function(diag)
      return ("[%s] %s"):format(diag.source, diag.message)
    end,
    -- nvim_open_win generic:
    relative = "cursor",
    style = "minimal",
    border = "rounded",
    -- open_floating_preview generic:
    focusable = true,
    -- lsp win specific:
    scope = "cursor",
    header = "",
  },
}
vim.keymap.set("n", "å", function()
  vim.diagnostic.jump(vim.tbl_extend("error", goto_win_opts, { count = -1 }))
end, { noremap = true, silent = true })
vim.keymap.set("n", "ß", function()
  vim.diagnostic.jump(vim.tbl_extend("error", goto_win_opts, { count = 1 }))
end, { noremap = true, silent = true })

-- mappings the rest
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("wax-lsp-attach", { clear = true }),
  callback = function(event)
    local buffer = event.buf

    local kmap_opts = { noremap = true, silent = true, buffer = buffer }

    -- See `:help vim.lsp.*` for documentation on any of the below functions

    vim.keymap.set("n", "gd", goto_first_definition, kmap_opts)
    vim.keymap.set("n", "<leader>d", goto_first_definition, kmap_opts)

    vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, kmap_opts)

    vim.keymap.set("n", "K", vim.lsp.buf.hover, kmap_opts)

    vim.keymap.set("n", "<leader>i", vim.lsp.buf.implementation, kmap_opts)
    vim.keymap.set("n", "<leader>I", vim.lsp.buf.declaration, kmap_opts)

    vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help)

    vim.keymap.set("n", "<leader>R", vim.lsp.buf.rename, kmap_opts)

    vim.keymap.set("n", "<leader>fa", vim.lsp.buf.code_action, kmap_opts)

    -- -- Formatting is done in conform.lua
    -- vim.keymap.set({ "n", "v" }, "<leader>m", function() vim.lsp.buf.format({ async = true }) end, kmap_opts)
  end,
})

--Enable completion triggered by <c-x><c-o>
vim.api.nvim_set_option_value("omnifunc", "v:lua.vim.lsp.omnifunc", {})

require("wax.lsp.ui")

-- Customization of the publishDiagnostics:
--   - remove all pyright diagnostics
vim.lsp.handlers[ms.textDocument_publishDiagnostics] = function(_, result, ctx)
  result.diagnostics = vim.tbl_filter(function(diagnostic)
    -- Filter out all diagnostics from pyright
    return not vim.tbl_contains({ "Pyright" }, diagnostic.source)
  end, result.diagnostics)
  vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx)
end
