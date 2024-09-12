-- Set log level for LSP
vim.lsp.set_log_level(waxopts.loglevel)

local function goto_alias_definition()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  local timeout = 1000

  for _, client in ipairs(clients) do
    if client.supports_method("textDocument/definition") then
      local resp = client.request_sync(
        "textDocument/definition",
        vim.lsp.util.make_position_params(),
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
          vim.lsp.util.jump_to_location(location, "utf-8")
          return
        end

        -- Special case of jump into redirection file: "imports.d.ts"
        -- Doing the equivalent of https://github.com/antfu/vscode-goto-alias
        local tmp_buf = vim.fn.bufadd(uri:sub(8))
        vim.fn.bufload(tmp_buf)

        local line_num = location["targetRange"]["end"]["line"]
        local lines = vim.api.nvim_buf_get_lines(tmp_buf, line_num, line_num + 1, false)
        local line_length = #lines[1] - 1

        local nested_resp = client.request_sync("textDocument/definition", {
          position = { line = line_num, character = line_length },
          textDocument = { uri = uri },
        }, timeout, bufnr)
        if nested_resp and nested_resp.result then
          local nested_location = nested_resp.result[1]
          vim.lsp.util.jump_to_location(nested_location, "utf-8")
        end

        vim.api.nvim_buf_delete(tmp_buf, { force = true })
      end
    end
  end
end

-- copy pasted and adapted from: runtime/lua/vim/lsp/buf.lua
local function custom_rename(new_name, opts)
  local util = require("vim.lsp.util")
  local ms = require("vim.lsp.protocol").Methods
  local api = vim.api

  opts = opts or {}
  local bufnr = opts.bufnr or api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    name = opts.name,
    -- Clients must at least support rename, prepareRename is optional
    method = ms.textDocument_rename,
  })
  if opts.filter then
    clients = vim.tbl_filter(opts.filter, clients)
  end

  if #clients == 0 then
    vim.notify("[LSP] Rename, no matching language servers with rename capability.")
  end

  local win = api.nvim_get_current_win()

  -- Compute early to account for cursor movements after going async
  local cword = vim.fn.expand("<cword>")

  local function get_text_at_range(range, offset_encoding)
    return api.nvim_buf_get_text(
      bufnr,
      range.start.line,
      util._get_line_byte_from_position(bufnr, range.start, offset_encoding),
      range["end"].line,
      util._get_line_byte_from_position(bufnr, range["end"], offset_encoding),
      {}
    )[1]
  end

  local function try_use_client(idx, client)
    if not client then
      return
    end

    --- @param name string
    local function rename(name)
      local params = util.make_position_params(win, client.offset_encoding)
      params.newName = name
      local handler = client.handlers[ms.textDocument_rename]
        or vim.lsp.handlers[ms.textDocument_rename]
      client.request(ms.textDocument_rename, params, function(...)
        vim.cmd("mkview")
        handler(...)
        vim.cmd("loadview")
        try_use_client(next(clients, idx))
      end, bufnr)
    end

    if client.supports_method(ms.textDocument_prepareRename) then
      local params = util.make_position_params(win, client.offset_encoding)
      client.request(ms.textDocument_prepareRename, params, function(err, result)
        if err or result == nil then
          if next(clients, idx) then
            try_use_client(next(clients, idx))
          else
            local msg = err and ("Error on prepareRename: " .. (err.message or ""))
              or "Nothing to rename"
            vim.notify(msg, vim.log.levels.INFO)
          end
          return
        end

        if new_name then
          rename(new_name)
          return
        end

        local prompt_opts = {
          prompt = "New Name: ",
        }
        -- result: Range | { range: Range, placeholder: string }
        if result.placeholder then
          prompt_opts.default = result.placeholder
        elseif result.start then
          prompt_opts.default = get_text_at_range(result, client.offset_encoding)
        elseif result.range then
          prompt_opts.default = get_text_at_range(result.range, client.offset_encoding)
        else
          prompt_opts.default = cword
        end
        vim.ui.input(prompt_opts, function(input)
          if not input or #input == 0 then
            return
          end
          rename(input)
        end)
      end, bufnr)
    else
      assert(
        client.supports_method(ms.textDocument_rename),
        "Client must support textDocument/rename"
      )
      if new_name then
        rename(new_name)
        return
      end

      local prompt_opts = {
        prompt = "New Name: ",
        default = cword,
      }
      vim.ui.input(prompt_opts, function(input)
        if not input or #input == 0 then
          return
        end
        rename(input)
      end)
    end
  end

  try_use_client(next(clients))
end

-- Mappings
local function set_lsp_keymaps(buffer)
  local kmap_opts = { noremap = true, silent = true, buffer = buffer }

  -- See `:help vim.lsp.*` for documentation on any of the below functions
  vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, kmap_opts)

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
  vim.keymap.set("n", "gd", goto_first_definition, kmap_opts)
  vim.keymap.set("n", "<leader>d", goto_first_definition, kmap_opts)

  vim.keymap.set("n", "K", vim.lsp.buf.hover, kmap_opts)

  vim.keymap.set("n", "<leader>i", vim.lsp.buf.implementation, kmap_opts)
  vim.keymap.set("n", "<leader>I", vim.lsp.buf.declaration, kmap_opts)

  vim.keymap.set("i", "<C-s>", vim.lsp.buf.signature_help)

  vim.keymap.set("n", "<leader>R", custom_rename, kmap_opts)

  -- Mapping with selectors:
  vim.keymap.set("n", "<leader>fa", vim.lsp.buf.code_action, kmap_opts)

  -- -- Formatting is done in conform.lua
  -- vim.keymap.set({ "n", "v" }, "<leader>m", function()
  --   vim.lsp.buf.format({ async = true })
  -- end, kmap_opts)
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
  vim.diagnostic.goto_prev(goto_win_opts)
end, { noremap = true, silent = true })
vim.keymap.set("n", "ß", function()
  vim.diagnostic.goto_next(goto_win_opts)
end, { noremap = true, silent = true })

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

  if is_module_available("cmp_nvim_lsp") then
    capabilities.textDocument.completion =
      require("cmp_nvim_lsp").default_capabilities({}).textDocument.completion
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
