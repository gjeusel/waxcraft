local ms = require("vim.lsp.protocol").Methods

-- Set log level for LSP
vim.lsp.set_log_level(waxopts.loglevel)

local function goto_alias_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  local timeout = 1000

  for _, client in ipairs(clients) do
    if client.supports_method(ms.textDocument_definition) then
      local resp = client.request_sync(
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

-- Mappings
local function set_lsp_keymaps(buffer)
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
end

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

-- Customization of the publishDiagnostics:
--   - remove all pyright diagnostics
vim.lsp.handlers[ms.textDocument_publishDiagnostics] = function(_, result, ctx)
  result.diagnostics = vim.tbl_filter(function(diagnostic)
    -- Filter out all diagnostics from pyright
    return not vim.tbl_contains({ "Pyright" }, diagnostic.source)
  end, result.diagnostics)

  vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx)
end

-- Disable semanticTokens on lsp attach
--
-- should be done in on_attach setting it to nil, but buggy right now:
-- https://github.com/neovim/neovim/issues/21588
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    -- disable semanticTokens for now
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf
    vim.lsp.semantic_tokens.stop(bufnr, client.id)
    client.server_capabilities.semanticTokensProvider = nil
  end,
})

-- Add auto disable client following waxopts.servers defs
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    if not args.data then
      return
    end

    local lsp_client = vim.lsp.get_client_by_id(args.data.client_id)
    local opts = vim.tbl_get(waxopts.servers, lsp_client.name)

    local project = find_workspace_name(args.file)
    if opts and vim.tbl_contains(opts.blacklist, project) then
      log.debug("Disabling", lsp_client.name, "for project", project)
      lsp_client.cancel_request(args.id)
      -- failing as not attached yet when not using defer_fn, the fuck? resort to defer
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_loaded(args.buf) then
          vim.lsp.buf_detach_client(args.buf, args.data.client_id)
        end
      end, 500)
    end
  end,
})

local Path = require("wax.path")

local function create_mason_handlers()
  -- Generate capabilities
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  -- if is_module_available("cmp_nvim_lsp") then
  --   capabilities.textDocument.completion =
  --     require("cmp_nvim_lsp").default_capabilities({}).textDocument.completion
  -- end

  if is_module_available("blink.cmp") then
    capabilities.textDocument.completion =
      require("blink.cmp").get_lsp_capabilities({}).textDocument.completion
  end

  local handlers = {}

  local server_with_custom_config = vim.tbl_map(function(path)
    return vim.fn.fnamemodify(path.path, ":t:r")
  end, Path.waxdir():join("lsp/servers"):ls())

  for _, server_name in ipairs(server_with_custom_config) do
    local server_module = ("wax.lsp.servers.%s"):format(server_name)
    local server_custom_opts = require(server_module)

    if type(server_custom_opts) == "table" then
      handlers[server_name] = function()
        require("lspconfig")[server_name].setup(
          vim.tbl_deep_extend("keep", { capabilities = capabilities }, server_custom_opts)
        )
      end
    end
  end

  return handlers
end

return {
  setup_ui = function()
    require("wax.lsp.ui")
  end,
  set_lsp_keymaps = set_lsp_keymaps,
  create_mason_handlers = create_mason_handlers,
}
