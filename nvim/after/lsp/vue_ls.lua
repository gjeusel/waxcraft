-- vue-language-server v3.3+ resolves TypeScript from a `--tsdk=` CLI flag
-- (init_options.typescript.tsdk is ignored), falling back to its own bundled
-- typescript — which mason installs as TS 7 (native preview) whose JS API has
-- no `ts.server.protocol`, crashing the server on startup. Point it at the
-- TS 5.x bundled with vtsls instead.
local tsdk = vim.fn.expand(
  "$MASON/packages/vtsls/node_modules/@vtsls/language-server/node_modules/typescript/lib"
)

return {
  cmd = { "vue-language-server", "--stdio", "--tsdk=" .. tsdk },
}
