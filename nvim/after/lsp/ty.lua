-- Check if pyproject.toml contains [tool.ty] section, cached per root_dir
local _cache = {}
local function has_tool_ty(root_dir)
  if root_dir == nil then
    return false
  end
  if _cache[root_dir] ~= nil then
    return _cache[root_dir]
  end
  local found = vim.fs.find("pyproject.toml", { path = root_dir, upward = false, type = "file" })
  if #found == 0 then
    _cache[root_dir] = false
    return false
  end
  local lines = vim.fn.readfile(found[1])
  for _, line in ipairs(lines) do
    if line:match("^%[tool%.ty") then
      _cache[root_dir] = true
      return true
    end
  end
  _cache[root_dir] = false
  return false
end

return {
  -- Silence ty server panics (e.g. https://github.com/astral-sh/ty/issues/2401)
  on_error = function(_, _) end,
  handlers = {
    -- Only show diagnostics when [tool.ty] is configured in pyproject.toml
    ["textDocument/publishDiagnostics"] = function(err, result, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client and has_tool_ty(client.root_dir) then
        vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
      end
    end,
    ["textDocument/diagnostic"] = function(err, result, ctx)
      local client = vim.lsp.get_client_by_id(ctx.client_id)
      if client and has_tool_ty(client.root_dir) then
        return vim.lsp.diagnostic.on_diagnostic(err, result, ctx)
      end
      return { kind = "full", items = {} }
    end,
    ["window/showMessage"] = function(_, result)
      if result and result.type == vim.lsp.protocol.MessageType.Error then
        return -- silence error notifications from ty
      end
    end,
  },
  settings = {
    ty = {
      experimental = {
        rename = true, -- https://docs.astral.sh/ty/reference/editor-settings/#rename
        autoImport = true,
      },
    },
  },
}
