-- Set log level for LSP
vim.lsp.set_log_level(waxopts.loglevel)

local function _lsp_to_single_location(err, locations)
  if err or locations == nil or vim.tbl_isempty(locations) then
    return
  end
  return locations[1]
end

local function custom_go_to_definition()
  local params = vim.lsp.util.make_position_params()
  vim.lsp.buf_request(0, "textDocument/definition", params, function(err, locations)
    local location = _lsp_to_single_location(err, locations)
    if not location then
      return
    end

    vim.lsp.util.jump_to_location(location, "utf-8")

    -- Special case of nested goto definition (on generated typescript files)
    if string.match(location.uri or location.targetUri, ".*imports.d.ts") then
      local line_num = location["targetRange"]["end"]["line"]
      local buf = vim.api.nvim_get_current_buf()
      local line_length = #vim.api.nvim_buf_get_lines(buf, line_num, line_num + 1, false)[1]

      local next_position = {
        position = { character = line_length - 1, line = line_num },
        textDocument = { uri = location.targetUri },
      }
      vim.lsp.buf_request(
        0,
        "textDocument/definition",
        next_position,
        function(nested_err, nested_locations)
          local nested_location = _lsp_to_single_location(nested_err, nested_locations)
          if nested_location then
            vim.api.nvim_buf_delete(0, { force = true }) -- remove buffer of import.d.ts
            vim.lsp.util.jump_to_location(nested_location, "utf-8")
          end
        end
      )
    end
  end)
end

-- Mappings
local function set_lsp_keymaps()
  local opts = { noremap = true, silent = true }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)

  local function goto_first_definition()
    vim.lsp.buf.definition({
      on_list = function(options)
        vim.fn.setqflist({}, " ", options)
        vim.api.nvim_command("silent! cfirst!")
      end,
    })
  end
  vim.keymap.set("n", "gd", goto_first_definition, opts)
  vim.keymap.set("n", "<leader>d", goto_first_definition, opts)

  vim.keymap.set("n", "gd", custom_go_to_definition, opts)
  vim.keymap.set("n", "<leader>d", custom_go_to_definition, opts)

  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

  vim.keymap.set("n", "<leader>i", vim.lsp.buf.implementation, opts)
  vim.keymap.set("n", "<leader>I", vim.lsp.buf.declaration, opts)

  vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help)

  vim.keymap.set("n", "<leader>R", vim.lsp.buf.rename, opts)

  -- Mapping with selectors:
  vim.keymap.set("n", "<leader>fa", vim.lsp.buf.code_action, opts)

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
    vim.diagnostic.goto_prev(goto_win_opts)
  end, opts)
  vim.keymap.set("n", "ß", function()
    vim.diagnostic.goto_next(goto_win_opts)
  end, opts)

  -- -- Formatting is done in conform.lua
  -- vim.keymap.set({ "n", "v" }, "<leader>m", function()
  --   vim.lsp.buf.format({ async = true })
  -- end, opts)
end

-- Customization of the publishDiagnostics (remove all pyright diags)
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(function(_, result, ctx, config)
  result.diagnostics = vim.tbl_filter(function(diagnostic)
    -- Filter out all diagnostics from pyright
    return not vim.tbl_contains({ "Pyright" }, diagnostic.source)
  end, result.diagnostics)

  vim.lsp.diagnostic.on_publish_diagnostics(_, result, ctx, config)
end, {})

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

    if not opts then
      return
    end

    local project = find_workspace_name(args.file)
    if vim.tbl_contains(opts.blacklist, project) then
      log.info("Disabling", lsp_client.name, "for project", project)
      -- failing as not attached yet when not using defer_fn, the fuck?
      vim.defer_fn(function()
        vim.lsp.buf_detach_client(args.buf, args.data.client_id)
      end, 3000)
    end
  end,
})

local Path = require("wax.path")

local function create_mason_handlers()
  -- Generate capabilities
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  if is_module_available("cmp_nvim_lsp") then
    capabilities.textDocument.completion =
      require("cmp_nvim_lsp").default_capabilities({}).textDocument.completion
  end

  local handlers = {}

  local server_with_custom_config = vim.tbl_map(function(path)
    return vim.fn.fnamemodify(path.path, ":t:r")
  end, Path.waxdir():join("lsp/servers"):ls())

  for _, server_name in ipairs(server_with_custom_config) do
    local function to_server_opts()
      local server_module = ("wax.lsp.servers.%s"):format(server_name)
      return vim.tbl_deep_extend("keep", { capabilities = capabilities }, require(server_module))
    end

    handlers[server_name] = function()
      require("lspconfig")[server_name].setup(to_server_opts())
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
